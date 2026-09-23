extends Node

## Juice — сервис «сочности» (game feel). Autoload-синглтон, доступен отовсюду как `Juice`.
##
## Идея: геймплейный код не должен знать, КАК делать красиво. Он говорит
## «произошло попадание» — `Juice.hit()`, «убили врага» — `Juice.kill()`,
## а что при этом происходит (замедление, тряска камеры, эффекты, в будущем звук)
## решается здесь, в одном месте, и тюнится через пресеты ниже.
##
## ── Как работает замедление времени (slow_motion) ──
##
## Engine.time_scale — глобальный множитель времени движка. При 0.1 все delta
## в _process/_physics_process, таймеры, твины и анимации идут в 10 раз медленнее.
## Поэтому сам Juice НЕ может мерить длительность замедления обычными delta/таймерами —
## они тоже замедлены. Он считает по реальному времени: Time.get_ticks_usec().
##
## Одно замедление проходит две фазы:
##   1. hold    — time_scale держится на `scale` в течение `hold` реальных секунд;
##   2. recover — time_scale плавно (ease-out) возвращается к 1.0 за `recover` сек.
##
##   time_scale
##   1.0 ────┐                    ╭──────
##           │                 ╭──╯
##           │              ╭──╯
##   scale   └──────────────╯
##           |<── hold ──>|<recover>|
##
## Если новое замедление приходит, пока идёт старое (например, два удара подряд),
## они сливаются: берётся более сильный scale и более поздний конец. Так эффекты
## не «обрезают» друг друга и время не дёргается.
##
## ── Удерживаемое замедление (hold_time_scale) ──
##
## slow_motion — короткий импульс, сам себя заканчивает. Для режимов, которые
## длятся сколько угодно (управление тенью), есть hold_time_scale(id, scale) /
## release_time_scale(id): замедление держится, пока его не отпустят по тому же id.
## Удержаний может быть несколько (разные id) — действует самое сильное.
## Итоговый Engine.time_scale = min(текущий импульс slow_motion, все удержания),
## поэтому удар во время замедления тенью всё равно даёт свой hit-stop поверх.
##
## ── Как работает тряска камеры (shake) ──
##
## Модель «травмы» (trauma): у Juice есть число trauma ∈ [0, 1].
## shake(amount) прибавляет к нему amount, а само оно каждую реальную секунду
## убывает на SHAKE_DECAY. Смещение камеры = SHAKE_MAX_OFFSET * trauma² * шум.
##   • квадрат — слабые удары почти не трясут, сильные трясут заметно,
##     и затухание выглядит мягким, а не линейным;
##   • несколько попаданий подряд складываются (до 1.0), тряска нарастает;
##   • шум — FastNoiseLite, а не randf: камера «плывёт» плавно, а не телепортируется
##     каждый кадр. Для X и Y — разные срезы одного шума, чтобы оси не совпадали.
##
## Трясём Camera2D.offset, а не position: position управляет следованием
## за игроком и сглаживанием, offset добавляется поверх и их не ломает.
## Камера — текущая камера вьюпорта (get_viewport().get_camera_2d()),
## её исходный offset запоминается и восстанавливается, когда тряска кончилась.
##
## Тряска тоже идёт по реальному времени: во время замедления она не должна
## застывать — именно сочетание «время почти стоит, а камеру трясёт» и даёт удар.
##
## process_mode = ALWAYS — чтобы Juice работал даже на паузе и всегда
## успевал вернуть time_scale в 1.0 и камеру на место.

# Пресеты: (scale, hold, recover). Тюнить здесь.
const HIT := Vector3(0.25, 0.06, 0.10)    # обычное попадание по врагу
const KILL := Vector3(0.10, 0.12, 0.25)   # добивание
const CLINCH := Vector3(0.15, 0.10, 0.20) # клинч — столкновение клинков

# Тряска: сколько trauma добавляет событие (0..1). Тюнить здесь.
const SHAKE_HIT := 0.35
const SHAKE_KILL := 0.6
const SHAKE_CLINCH := 0.5
const SHAKE_MAX_OFFSET := Vector2(8.0, 6.0) # px в мире при trauma = 1 (на экране × zoom камеры)
const SHAKE_DECAY := 1.6 # сколько trauma уходит за реальную секунду
const SHAKE_FREQUENCY := 25.0 # скорость движения по шуму — чем больше, тем «дрожательнее»

var _scale := 1.0        # минимальный time_scale текущего замедления
var _hold_until := 0     # usec: до этого момента держим _scale
var _recover_until := 0  # usec: к этому моменту возвращаемся к 1.0
var _active := false
var _holds := {} # StringName -> float: удерживаемые замедления

var _trauma := 0.0
var _shake_camera: Camera2D
var _camera_base_offset := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _last_usec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = randi()
	_noise.frequency = 1.0
	_last_usec = Time.get_ticks_usec()


# ── Высокоуровневые события: геймплей зовёт их ──

func hit() -> void:
	_apply_preset(HIT)
	shake(SHAKE_HIT)


func kill() -> void:
	_apply_preset(KILL)
	shake(SHAKE_KILL)


func clinch() -> void:
	_apply_preset(CLINCH)
	shake(SHAKE_CLINCH)


# ── Низкоуровневые эффекты ──

## Замедлить время до `scale` на `hold` реальных секунд, затем плавно вернуть за `recover` сек.
func slow_motion(scale: float, hold: float, recover: float) -> void:
	var now := Time.get_ticks_usec()
	var hold_until := now + int(hold * 1_000_000.0)
	var recover_until := hold_until + int(recover * 1_000_000.0)
	if _active:
		# Сливаем с текущим замедлением.
		scale = minf(scale, _scale)
		hold_until = maxi(hold_until, _hold_until)
		recover_until = maxi(recover_until, _recover_until)
	_scale = scale
	_hold_until = hold_until
	_recover_until = recover_until
	_active = true
	_apply_time_scale(now)


## Встряхнуть текущую камеру: добавить amount (0..1) к trauma.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## Заспавнить одноразовый эффект (частицы и т.п.) в корень текущего уровня.
## dir — куда повернуть эффект: его локальная ось +X смотрит по dir.
## CPUParticles2D/GPUParticles2D запускаются сами и удаляются по сигналу finished;
## любая другая сцена с сигналом finished тоже удалится по нему.
## Эффекты живут в игровом времени — во время slow_motion брызги тоже замедлены.
func spawn_effect(scene: PackedScene, pos: Vector2, dir := Vector2.RIGHT) -> Node2D:
	var level := get_tree().current_scene
	if scene == null or level == null:
		return null
	var fx := scene.instantiate() as Node2D
	level.add_child(fx)
	fx.global_position = pos
	fx.rotation = dir.angle()
	if fx is CPUParticles2D or fx is GPUParticles2D:
		fx.restart()
	if fx.has_signal("finished"):
		fx.finished.connect(fx.queue_free)
	return fx


## Держать замедление scale, пока не вызовут release_time_scale(id).
func hold_time_scale(id: StringName, scale: float) -> void:
	_holds[id] = scale
	_apply_time_scale(Time.get_ticks_usec())


func release_time_scale(id: StringName) -> void:
	_holds.erase(id)
	_apply_time_scale(Time.get_ticks_usec())


## Немедленно вернуть нормальное время (сбрасывает и импульс, и все удержания).
func reset() -> void:
	_active = false
	_holds.clear()
	Engine.time_scale = 1.0


func _apply_preset(p: Vector3) -> void:
	slow_motion(p.x, p.y, p.z)


func _process(_delta: float) -> void:
	# _delta замедлен time_scale — считаем реальное время сами.
	var now := Time.get_ticks_usec()
	var real_delta := float(now - _last_usec) / 1_000_000.0
	_last_usec = now
	_update_shake(now, real_delta)
	_apply_time_scale(now)


func _update_shake(now: int, real_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != _shake_camera:
		# Камера сменилась (перезагрузка сцены и т.п.) — вернуть старую на место.
		if is_instance_valid(_shake_camera):
			_shake_camera.offset = _camera_base_offset
		_shake_camera = camera
		if camera:
			_camera_base_offset = camera.offset
	if camera == null:
		return

	if _trauma <= 0.0:
		return
	_trauma = maxf(_trauma - SHAKE_DECAY * real_delta, 0.0)
	var t := float(now) / 1_000_000.0 * SHAKE_FREQUENCY
	var power := _trauma * _trauma
	camera.offset = _camera_base_offset + Vector2(
		SHAKE_MAX_OFFSET.x * power * _noise.get_noise_2d(t, 0.0),
		SHAKE_MAX_OFFSET.y * power * _noise.get_noise_2d(0.0, t + 100.0),
	)


## Итоговый time_scale = min(импульс slow_motion, удержания).
func _apply_time_scale(now: int) -> void:
	var t_scale := 1.0
	if _active:
		if now < _hold_until:
			t_scale = _scale
		elif now < _recover_until:
			var t := float(now - _hold_until) / float(_recover_until - _hold_until)
			t_scale = lerpf(_scale, 1.0, ease(t, 0.4)) # 0.4 — ease-out: быстро разгоняется, мягко доходит до 1
		else:
			_active = false
	for h: float in _holds.values():
		t_scale = minf(t_scale, h)
	Engine.time_scale = t_scale
