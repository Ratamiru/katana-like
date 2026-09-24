class_name DialogueRunner
extends RefCounted

## Исполняет скомпилированный диалог по шагам. Ничего не знает про UI:
##
##   var line := runner.next()   # следующая реплика (или null — диалог кончился)
##   if line.has_choices():
##       runner.choose(i)        # игрок выбрал вариант i
##
## Выражения (условия, set, do, {подстановки}) вычисляет `evaluator` — обычно autoload Dialogue
## (метод evaluate(expr, ids, locals) и словарь vars). Поэтому раннер легко гонять в тестах.

signal line_ready(line: DialogueLine)
signal finished

const MAX_STEPS := 10000 # защита от цикла без реплик (=> a в узле a)

var resource: DialogueResource
var evaluator: Object
var locals := {}
var is_finished := false

var _ip := -1
var _waiting_choice := false
var _options: Array[Dictionary] = []


func _init(res: DialogueResource, eval: Object, locals_ := {}) -> void:
	resource = res
	evaluator = eval
	locals = locals_


func start(node := "start") -> bool:
	if not resource.nodes.has(node):
		push_error("Dialogue: нет узла «%s»" % node)
		_finish()
		return false
	_ip = resource.nodes[node]
	_visit(node)
	return true


## Выполняет инструкции до следующей реплики/выбора. null — диалог закончился.
func next() -> DialogueLine:
	if is_finished:
		return null
	if _waiting_choice:
		push_error("Dialogue: сначала нужно выбрать вариант — choose()")
		return null
	var code := resource.code
	for _step in MAX_STEPS:
		if _ip < 0 or _ip >= code.size():
			break
		var ins: Dictionary = code[_ip]
		match ins.op:
			"line":
				var line := DialogueLine.new()
				line.speaker = _interpolate(tr(ins.speaker))
				line.text = _interpolate(tr(ins.text))
				line.tags = ins.tags
				line.source_line = ins.line
				_ip += 1
				# Выбор сразу после реплики (в т.ч. после конца if-ветки или через =>)
				# показывается вместе с ней. Переходы — без побочных эффектов, их можно пройти заранее.
				for _hop in 64: # 64 — защита от цикла из одних =>
					if _ip >= code.size() or code[_ip].op not in ["jump", "goto"]:
						break
					if code[_ip].op == "goto":
						_visit(code[_ip].node)
					_ip = code[_ip].to
				if _ip < code.size() and code[_ip].op == "choice":
					_offer(code[_ip], line)
				line_ready.emit(line)
				return line
			"choice":
				var line := DialogueLine.new()
				line.source_line = ins.line
				_offer(ins, line)
				if line.has_choices():
					line_ready.emit(line)
					return line
			"if":
				_ip = _ip + 1 if _eval(ins.expr, ins.ids) else ins.else_to
			"jump":
				_ip = ins.to
			"goto":
				_visit(ins.node)
				_ip = ins.to
			"set":
				evaluator.vars[ins.name] = _eval(ins.expr, ins.ids)
				_ip += 1
			"do":
				_eval(ins.expr, ins.ids)
				_ip += 1
			"end":
				break
	if _ip >= 0 and _ip < code.size() and code[_ip].op != "end":
		push_error("Dialogue: больше %d шагов без реплики — зацикленный переход?" % MAX_STEPS)
	_finish()
	return null


## Выбрать вариант из последней реплики (индекс в line.choices).
func choose(index: int) -> void:
	if not _waiting_choice or index < 0 or index >= _options.size():
		push_error("Dialogue: неверный выбор %d" % index)
		return
	var opt := _options[index]
	if opt.once:
		_memory("once")[_key(opt.id)] = true
	_ip = opt.to
	_waiting_choice = false
	_options.clear()


## Сколько раз заходили в узел (через start или =>). Доступно в диалоге как visited("узел").
func visits(node: String) -> int:
	return _memory("visits").get(_key(node), 0)


func stop() -> void:
	_finish()


## Заполняет line.choices доступными вариантами; если их нет — выбор пропускается.
func _offer(ins: Dictionary, line: DialogueLine) -> void:
	_options.clear()
	var once := _memory("once")
	for opt: Dictionary in ins.options:
		if opt.once and once.has(_key(opt.id)):
			continue
		if opt.cond != "" and not _eval(opt.cond, opt.ids):
			continue
		_options.append(opt)
		line.choices.append({text = _interpolate(tr(opt.text)), tags = opt.tags})
	_waiting_choice = not _options.is_empty()
	if not _waiting_choice:
		_ip = ins.end


func _interpolate(text: String) -> String:
	if not text.contains("{"):
		return text
	var out := ""
	var last := 0
	for m in DialogueParser._re("\\{([^{}]+)\\}").search_all(text):
		var expr := m.get_string(1)
		out += text.substr(last, m.get_start() - last) + str(_eval(expr, DialogueParser.identifiers(expr)))
		last = m.get_end()
	return out + text.substr(last)


func _eval(expr: String, ids: PackedStringArray) -> Variant:
	return evaluator.evaluate(expr, ids, locals, self)


func _visit(node: String) -> void:
	var visits_ := _memory("visits")
	visits_[_key(node)] = visits_.get(_key(node), 0) + 1


## Служебная память диалогов лежит в vars (__once, __visits) — сохраняется вместе с ними.
func _memory(kind: String) -> Dictionary:
	var k := "__" + kind
	if not evaluator.vars.has(k):
		evaluator.vars[k] = {}
	return evaluator.vars[k]


func _key(id: String) -> String:
	return "%s:%s" % [resource.resource_path, id]


func _finish() -> void:
	if is_finished:
		return
	is_finished = true
	_waiting_choice = false
	finished.emit()
