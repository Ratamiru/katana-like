class_name ShadowAbility
extends Node

## Способность «тень» — компонент основного тела игрока.
##
## Цикл:
##   READY ──[shadow]──► CONTROLLING ──[attack: захват]──► HOLDING ──[hold_time]──► COOLDOWN ──► READY
##                           │                                                         ▲
##                           └──[shadow ещё раз / вышло max_control_time]──────────────┘
##
##   CONTROLLING — тень заспавнена у тела, мир замедлен (Juice.hold_time_scale),
##                 управление у тени (PlayerPawn.possess), основное тело стоит и уязвимо.
##   HOLDING     — тень схватила врага: управление и нормальное время сразу
##                 возвращаются телу, тень держит врага hold_time сек и исчезает.
##   COOLDOWN    — тени нет, ждём cooldown сек.
##
## Все длительности CONTROLLING — в реальном времени (мир же замедлен).

enum State { READY, CONTROLLING, HOLDING, COOLDOWN }

signal state_changed(state: State)

const TIME_HOLD_ID := &"shadow"

@export var shadow_scene: PackedScene
@export var world_time_scale := 0.4 # замедление мира, пока управляешь тенью
@export var max_control_time := 3.0 # реальных сек под управлением тени, потом она исчезает сама
@export var cooldown := 3.0 # сек после исчезновения тени до следующего использования

var state := State.READY
var _shadow: Shadow
var _timer := 0.0

@onready var body: PlayerPawn = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("shadow") or body.is_dead:
		return
	match state:
		State.READY:
			_activate()
		State.CONTROLLING:
			_end(true) # отменить досрочно


func _process(delta: float) -> void:
	# delta замедлен time_scale — в CONTROLLING считаем реальное время.
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	match state:
		State.CONTROLLING:
			_timer -= real_delta
			if _timer <= 0.0 or not is_instance_valid(_shadow):
				_end(true)
		State.HOLDING:
			_timer -= delta # держит врага в игровом времени, как и сам захват
			if _timer <= 0.0:
				_end(false)
		State.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0:
				_set_state(State.READY)


func _activate() -> void:
	var level := get_tree().current_scene
	if shadow_scene == null or level == null:
		return
	_shadow = shadow_scene.instantiate() as Shadow
	level.add_child(_shadow)
	_shadow.global_position = body.global_position
	_shadow.facing = body.facing
	_shadow.grabbed.connect(_on_shadow_grabbed)

	Juice.hold_time_scale(TIME_HOLD_ID, world_time_scale)
	ScreenFX.enter(TIME_HOLD_ID)
	PlayerPawn.possess(_shadow)
	_timer = max_control_time
	_set_state(State.CONTROLLING)


func _on_shadow_grabbed(_target: Node) -> void:
	# Захват: управление и время — телу, тень держит врага.
	Juice.release_time_scale(TIME_HOLD_ID)
	ScreenFX.exit(TIME_HOLD_ID)
	PlayerPawn.possess(body)
	_timer = _shadow.grab_attack.hold_time
	_set_state(State.HOLDING)


## Убрать тень и уйти в кулдаун. return_control — вернуть управление/время (если ещё не вернули).
func _end(return_control: bool) -> void:
	if return_control:
		Juice.release_time_scale(TIME_HOLD_ID)
		ScreenFX.exit(TIME_HOLD_ID)
		PlayerPawn.possess(body)
	if is_instance_valid(_shadow):
		_shadow.vanish()
	_shadow = null
	_timer = cooldown
	_set_state(State.COOLDOWN)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)


func _exit_tree() -> void:
	# Тело удалилось (смерть/перезагрузка) — не оставить мир замедленным и экран фиолетовым.
	Juice.release_time_scale(TIME_HOLD_ID)
	ScreenFX.exit(TIME_HOLD_ID)
