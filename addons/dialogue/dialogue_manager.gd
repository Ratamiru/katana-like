extends Node

## Autoload `Dialogue` — точка входа системы диалогов.
##
##   Dialogue.start(preload("res://dialogues/npc.dlg"))            # показать диалог
##   Dialogue.start("res://dialogues/npc.dlg", "shop", {npc = self}) # с узла shop + локальные имена
##   await Dialogue.ended
##
## ── Состояние ──
##
## vars — все переменные диалогов (set x = …), общий словарь на игру. Сохраняете его —
## сохраняете и выборы игрока. Туда же раннер кладёт служебные __once / __visits.
##
## ── Что видно из выражений диалога (if / set / do / {…}) ──
##
## Имя ищется по порядку:
##   1. locals, переданные в start() (например npc, trigger);
##   2. vars;
##   3. ноды прямо под /root — это все autoload'ы: `do Juice.shake(0.3)`;
##   4. синглтоны движка (Input, Engine…) и глобальные классы (class_name) — для static;
##   5. иначе 0 (ведёт себя как false: `if not met` работает до первого set).
## Функции без точки — методы этого менеджера: emit(), node(), visited(), get_var().
##
## ── UI ──
##
## По умолчанию показывается DialogueBalloon. Своё окно: balloon_scene = preload("my.tscn"),
## корень сцены должен иметь метод run(runner: DialogueRunner) и сам вызывать next()/choose().
## Или вообще без окна: create_runner() и крутить раннер вручную.

signal started(resource: DialogueResource)
signal ended(resource: DialogueResource)
signal line_shown(line: DialogueLine)
## `do emit("open_gate", 3)` в диалоге → event(&"open_gate", [3]).
signal event(event_name: StringName, args: Array)

var vars := {}
var balloon_scene: PackedScene
var pause_game := true # ставить дерево на паузу на время диалога (окно работает всё равно)
var current: DialogueRunner

var _balloon: Node
var _was_paused := false
var _expr_cache := {}
var _evaluating: DialogueRunner # раннер, чьё выражение сейчас считается


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	return current != null


## Показать диалог. dialogue — DialogueResource или путь к .dlg.
func start(dialogue: Variant, node := "start", locals := {}) -> DialogueRunner:
	if is_active():
		push_warning("Dialogue: диалог уже идёт")
		return null
	var runner := create_runner(dialogue, node, locals)
	if runner == null or runner.is_finished:
		return null
	current = runner
	runner.line_ready.connect(line_shown.emit)
	runner.finished.connect(_on_finished.bind(runner), CONNECT_ONE_SHOT)
	if pause_game:
		_was_paused = get_tree().paused
		get_tree().paused = true
	_balloon = balloon_scene.instantiate() if balloon_scene else DialogueBalloon.new()
	add_child(_balloon)
	started.emit(runner.resource)
	_balloon.run(runner)
	return runner


## Раннер без UI — для своего окна, катсцен, тестов.
func create_runner(dialogue: Variant, node := "start", locals := {}) -> DialogueRunner:
	var res: DialogueResource = load(dialogue) if dialogue is String else dialogue
	if res == null:
		push_error("Dialogue: не удалось загрузить %s" % [dialogue])
		return null
	var runner := DialogueRunner.new(res, self, locals)
	runner.start(node)
	return runner


## Прервать текущий диалог.
func stop() -> void:
	if current:
		current.stop()


## Вычислить выражение в контексте диалога (см. порядок поиска имён в шапке).
## runner — чей диалог сейчас вычисляется (для visited()); по умолчанию текущий.
func evaluate(expr: String, ids: Variant = null, locals := {}, runner: DialogueRunner = null) -> Variant:
	if ids == null:
		ids = DialogueParser.identifiers(expr)
	var e: Expression = _expr_cache.get(expr)
	if e == null:
		e = Expression.new()
		if e.parse(expr, ids) != OK:
			push_error("Dialogue: «%s» — %s" % [expr, e.get_error_text()])
			return null
		_expr_cache[expr] = e
	var values := []
	for id: String in ids:
		values.append(_resolve(id, locals))
	var prev := _evaluating
	_evaluating = runner
	var result: Variant = e.execute(values, self, false)
	_evaluating = prev
	if e.has_execute_failed():
		push_error("Dialogue: «%s» — %s" % [expr, e.get_error_text()])
		return null
	return result


# ── Функции, доступные в диалоге без точки ──

## Сигнал event(имя, [аргументы]) — связка диалога с игрой без знания о конкретных нодах.
func emit(event_name: String, ...args: Array) -> void:
	event.emit(StringName(event_name), args)


## Нода текущей сцены по пути или имени: `do node("Door").set_active(true)`.
func node(path: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var n := scene.get_node_or_null(path)
	if n == null:
		n = scene.find_child(path, true, false)
	if n == null:
		push_warning("Dialogue: нода «%s» не найдена" % path)
	return n


## Сколько раз в текущем диалоге заходили в узел.
func visited(node_name: String) -> int:
	var r := _evaluating if _evaluating else current
	return r.visits(node_name) if r else 0


func get_var(var_name: String, default: Variant = null) -> Variant:
	return vars.get(var_name, default)


func _resolve(id: String, locals: Dictionary) -> Variant:
	if locals.has(id):
		return locals[id]
	if vars.has(id):
		return vars[id]
	var n := get_tree().root.get_node_or_null(NodePath(id))
	if n:
		return n
	if Engine.has_singleton(id):
		return Engine.get_singleton(id)
	for c in ProjectSettings.get_global_class_list():
		if c.class == id:
			return load(c.path)
	return 0


func _on_finished(runner: DialogueRunner) -> void:
	if _balloon:
		_balloon.queue_free()
		_balloon = null
	# Кадр паузы: нажатие, закрывшее диалог, не должно тут же стать прыжком/ударом.
	await get_tree().process_frame
	if pause_game:
		get_tree().paused = _was_paused
	current = null
	ended.emit(runner.resource)
