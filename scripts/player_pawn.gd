class_name PlayerPawn
extends Fighter

## Тело, которым может управлять игрок (pawn): основное тело (character.gd) или тень (shadow.gd).
##
## ── Как передаётся управление ──
##
## Управляемое тело в каждый момент ровно одно — его хранит статическая ссылка
## PlayerPawn.possessed. Это и есть «булеан», только без рассинхрона: нельзя
## случайно получить два тела с is_possessed = true или ни одного.
##   • possess(pawn) — передать управление: меняет possessed и делает текущей камеру этого тела;
##   • is_possessed() — «я сейчас под управлением?» — possessed == self.
##
## Каждое тело само читает инпут, но только если is_possessed(). Остальные тела
## получают нулевые намерения — стоят (гравитация и физика продолжают работать).
## Действие на `attack` у каждого тела своё: _primary_action() (катана / захват).

static var possessed: PlayerPawn

@onready var camera: Camera2D = get_node_or_null("Camera2D")
## Косметический свет вокруг тела (НЕ LightSource — не делает игрока «освещённым» для врагов).
@onready var view_light: PointLight2D = get_node_or_null("ViewLight")


func _ready() -> void:
	super()
	# На полностью освещённом уровне (LevelLighting.fully_lit) свой свет не нужен.
	if view_light:
		view_light.visible = not LightSource.level_fully_lit


## Передать управление телу pawn.
static func possess(pawn: PlayerPawn) -> void:
	possessed = pawn
	if pawn and pawn.camera:
		pawn.camera.enabled = true # у тени камера выключена в сцене, чтобы не перехватить вид при спавне
		pawn.camera.make_current()
		pawn.camera.reset_smoothing()


func is_possessed() -> bool:
	return possessed == self


func _update_intent(_delta: float) -> void:
	if not is_possessed():
		move_dir = 0.0
		jump_requested = false
		drop_requested = false
		return
	move_dir = Input.get_axis("backward", "forward")
	jump_requested = Input.is_action_just_pressed("jump")
	drop_requested = Input.is_action_pressed("down")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and is_possessed() and not is_dead:
		_primary_action()


## Действие на `attack`. Переопределяется наследниками.
func _primary_action() -> void:
	pass


func _exit_tree() -> void:
	if possessed == self:
		possessed = null
