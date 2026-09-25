class_name Switch
extends Area2D

## Переключатель — база для всего, что включает/выключает объекты уровня:
## рычаг (удар катаной), в будущем кнопка/нажимная плита/терминал.
##
## ── Как связывается с уровнем ──
##
## В инспекторе в `targets` перетаскиваются ноды, которыми управляет переключатель.
## Цель — ЛЮБАЯ нода с методом `set_active(on: bool)` (дверь, платформа, турель, свет…).
## При переключении у всех целей вызывается set_active(is_on), и эмитится switched(is_on) —
## к сигналу можно подключить что угодно прямо в редакторе, без кода.
##
## Переключатель — Area2D на слое 5 (пропы): его «видит» хитбокс MeleeAttack,
## но он не мешает ходить и не останавливает пули.
## Удар приходит через HitReaction.dispatch → on_hit(hit).
##
## Режимы:
##   TOGGLE — каждое срабатывание переключает вкл/выкл;
##   ONCE   — включается один раз и больше не реагирует;
##   TIMED  — включается на timed_duration сек (игровое время), потом выключается сам.

signal switched(on: bool)

enum Mode { TOGGLE, ONCE, TIMED }

@export var targets: Array[NodePath] = []
@export var mode := Mode.TOGGLE
@export var start_on := false
@export var timed_duration := 3.0
@export var hit_kinds: Array[StringName] = [&"melee"] # какие удары переключают (пусто — любые)
## Можно переключить взаимодействием (тень, Interactor), а не только ударом.
@export var interactable := true

var is_on := false
var _used := false
var _timer: SceneTreeTimer


func _ready() -> void:
	collision_layer = 0b10000 # слой 5 — пропы
	collision_mask = 0
	monitoring = false
	monitorable = true
	is_on = start_on
	_update_visual(false)
	# Цели могут быть ещё не готовы — выставим им начальное состояние в конце кадра.
	_apply_to_targets.call_deferred()


## Вызывается HitReaction.dispatch при попадании.
func on_hit(hit: HitInfo) -> void:
	if not hit_kinds.is_empty() and hit.kind not in hit_kinds:
		return
	activate()


## Взаимодействие (Interactor тени и т.п.). true — сработало.
func interact(_actor: Node) -> bool:
	if not interactable:
		return false
	activate()
	return true


## Сработать (удар, взаимодействие, в будущем — нажатие кнопки, триггер и т.п.).
func activate() -> void:
	match mode:
		Mode.TOGGLE:
			set_on(not is_on)
		Mode.ONCE:
			if _used:
				return
			_used = true
			set_on(true)
		Mode.TIMED:
			set_on(true)
			if _timer:
				_timer.timeout.disconnect(_on_timer)
			_timer = get_tree().create_timer(timed_duration)
			_timer.timeout.connect(_on_timer)


func set_on(on: bool) -> void:
	if on == is_on:
		return
	is_on = on
	_update_visual(true)
	_apply_to_targets()
	switched.emit(is_on)


func _on_timer() -> void:
	_timer = null
	set_on(false)


func _apply_to_targets() -> void:
	for path in targets:
		var t := get_node_or_null(path)
		if t and t.has_method("set_active"):
			t.set_active(is_on)
		elif t == null:
			push_warning("%s: цель %s не найдена" % [name, path])


## Переопределяется наследниками: показать состояние (animated — плавно или сразу).
func _update_visual(_animated: bool) -> void:
	pass
