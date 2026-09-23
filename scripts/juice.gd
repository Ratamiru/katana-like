extends Node

## Juice — сервис «сочности» (game feel). Autoload-синглтон, доступен отовсюду как `Juice`.
##
## Идея: геймплейный код не должен знать, КАК делать красиво. Он говорит
## «произошло попадание» — `Juice.hit()`, «убили врага» — `Juice.kill()`,
## а что при этом происходит (замедление, в будущем тряска камеры, частицы, звук)
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
## process_mode = ALWAYS — чтобы Juice работал даже на паузе и всегда
## успевал вернуть time_scale в 1.0.

# Пресеты: (scale, hold, recover). Тюнить здесь.
const HIT := Vector3(0.25, 0.06, 0.10)    # обычное попадание по врагу
const KILL := Vector3(0.10, 0.12, 0.25)   # добивание
const CLINCH := Vector3(0.15, 0.10, 0.20) # клинч — столкновение клинков

var _scale := 1.0        # минимальный time_scale текущего замедления
var _hold_until := 0     # usec: до этого момента держим _scale
var _recover_until := 0  # usec: к этому моменту возвращаемся к 1.0
var _active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ── Высокоуровневые события: геймплей зовёт их ──

func hit() -> void:
	_apply_preset(HIT)


func kill() -> void:
	_apply_preset(KILL)


func clinch() -> void:
	_apply_preset(CLINCH)


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
	Engine.time_scale = _scale


## Немедленно вернуть нормальное время.
func reset() -> void:
	_active = false
	Engine.time_scale = 1.0


func _apply_preset(p: Vector3) -> void:
	slow_motion(p.x, p.y, p.z)


func _process(_delta: float) -> void:
	if not _active:
		return
	var now := Time.get_ticks_usec()
	if now < _hold_until:
		Engine.time_scale = _scale
	elif now < _recover_until:
		var t := float(now - _hold_until) / float(_recover_until - _hold_until)
		Engine.time_scale = lerpf(_scale, 1.0, ease(t, 0.4)) # 0.4 — ease-out: быстро разгоняется, мягко доходит до 1
	else:
		reset()
