@tool
class_name DialogueParser
extends RefCounted

## Компилирует текст .dlg в плоский список инструкций («байткод») + таблицу узлов.
##
## ── Почему плоский список, а не дерево ──
##
## Ветки (if / выборы) превращаются в условные переходы по индексам, как в ассемблере:
##
##   if gold > 5:          0: {op: if, expr: "gold > 5", else_to: 3}
##       A: богат          1: {op: line, "богат"}
##   else:                 2: {op: jump, to: 4}
##       A: беден          3: {op: line, "беден"}
##   A: пока               4: {op: line, "пока"}
##
## Раннеру остаётся только «указатель инструкции» _ip — прыжок в любой узел (=> name)
## и слияние веток после выбора получаются бесплатно, а состояние диалога — одно число.
##
## Инструкции (Dictionary, поле op):
##   line   {speaker, text, tags, line}
##   choice {options: [{text, cond, ids, once, tags, id, to}], end}
##   if     {expr, ids, else_to}
##   jump   {to}
##   goto   {node, to}
##   set    {name, expr, ids}
##   do     {expr, ids}
##   end    {}
## ids — идентификаторы из выражения; раннер подставляет их значения как входы Expression.
##
## Синтаксис — см. addons/dialogue/README.md.

const KEYWORDS := ["and", "or", "not", "true", "false", "null", "in", "self", "PI", "TAU", "INF", "NAN"]
const MAX_SPEAKER_LENGTH := 40

static var _regex_cache := {}

var _path := ""
var _lines: Array[Dictionary] = [] # {indent, text, line}
var _pos := 0
var _code: Array[Dictionary] = []
var _nodes := {}
var _gotos: Array[Dictionary] = [] # {ip, node, line}
var _errors := PackedStringArray()
var _node := ""


## Разобрать исходник. Возвращает {code, nodes, errors}.
static func parse(source: String, path := "") -> Dictionary:
	var p := DialogueParser.new()
	p._path = path
	return p._run(source)


## Идентификаторы выражения, которые надо подставить как входы Expression:
## без строк, ключевых слов, полей после точки и вызовов функций (`foo(` — метод менеджера).
static func identifiers(expr: String) -> PackedStringArray:
	var clean := _re("\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'").sub(expr, "\"\"", true)
	var out := PackedStringArray()
	for m in _re("(?<![\\w.])([A-Za-z_]\\w*)\\b(?!\\s*\\()").search_all(clean):
		var id := m.get_string(1)
		if id not in KEYWORDS and id not in out:
			out.append(id)
	return out


static func _re(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		_regex_cache[pattern] = RegEx.create_from_string(pattern)
	return _regex_cache[pattern]


func _run(source: String) -> Dictionary:
	_tokenize(source)
	while _pos < _lines.size():
		var l := _lines[_pos]
		if _is_header(l):
			_node = l.text.substr(1).strip_edges()
			if l.indent != 0:
				_error(l, "заголовок узла «~» пишется без отступа")
			if _node.is_empty():
				_error(l, "у узла нет имени")
			elif _nodes.has(_node):
				_error(l, "узел «%s» объявлен дважды" % _node)
			else:
				_nodes[_node] = _code.size()
			_pos += 1
		elif _nodes.is_empty():
			# Текст до первого заголовка — неявный узел start.
			_node = "start"
			_nodes[_node] = 0
		while _pos < _lines.size() and not _is_header(_lines[_pos]):
			_block(_lines[_pos].indent)
		_emit({op = "end"})

	for g in _gotos:
		if _nodes.has(g.node):
			_code[g.ip].to = _nodes[g.node]
		else:
			_error(g.line, "переход в неизвестный узел «%s»" % g.node)
	return {code = _code, nodes = _nodes, errors = _errors}


func _tokenize(source: String) -> void:
	var raw := source.split("\n")
	for i in raw.size():
		var s := raw[i].replace("\r", "")
		var text := s.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var indent := 0
		for c in s:
			if c == " ":
				indent += 1
			elif c == "\t":
				indent += 4
			else:
				break
		_lines.append({indent = indent, text = text, line = i + 1})


func _is_header(l: Dictionary) -> bool:
	return l.text.begins_with("~")


## Последовательность инструкций с отступом ровно `indent`.
func _block(indent: int) -> void:
	while _pos < _lines.size():
		var l := _lines[_pos]
		if l.indent < indent or _is_header(l):
			return
		if l.indent > indent:
			_error(l, "лишний отступ")
			_pos += 1
			continue
		_statement(l, indent)


## Вложенный блок (тело if / выбора), если следующая строка глубже `indent`.
func _child(indent: int) -> void:
	if _pos < _lines.size() and _lines[_pos].indent > indent and not _is_header(_lines[_pos]):
		_block(_lines[_pos].indent)


func _statement(l: Dictionary, indent: int) -> void:
	var t: String = l.text
	if t.begins_with("=>"):
		_goto(l)
	elif t.begins_with("- "):
		_choices(indent)
	elif _kw(t, "if"):
		_if(indent)
	elif _kw(t, "elif") or _kw(t, "else"):
		_error(l, "«%s» без «if»" % t.get_slice(" ", 0))
		_pos += 1
		_child(indent)
	elif _kw(t, "set"):
		_assignment(l)
	elif _kw(t, "do"):
		var expr := t.substr(2).strip_edges()
		_check_expr(expr, l)
		_emit({op = "do", expr = expr, ids = identifiers(expr), line = l.line})
		_pos += 1
	else:
		_line(l)
		_pos += 1


func _kw(t: String, word: String) -> bool:
	return t == word or t.begins_with(word + " ") or t.begins_with(word + ":")


func _goto(l: Dictionary) -> void:
	var target: String = l.text.substr(2).strip_edges()
	_pos += 1
	if target == "END":
		_emit({op = "end"})
	elif target.is_empty():
		_error(l, "после «=>» нужно имя узла или END")
	else:
		_gotos.append({ip = _code.size(), node = target, line = l})
		_emit({op = "goto", node = target, to = -1})


func _line(l: Dictionary) -> void:
	var parsed := _split_tags(l.text)
	var text: String = parsed[0]
	var speaker := ""
	if text.begins_with("\\"): # «\» в начале — принудительно текст (не команда)
		text = text.substr(1)
	var idx := text.find(": ")
	if idx > 0 and idx <= MAX_SPEAKER_LENGTH and text[idx - 1] != "\\" and not text.substr(0, idx).contains("{"):
		speaker = text.substr(0, idx).strip_edges()
		text = text.substr(idx + 2).strip_edges()
	text = text.replace("\\:", ":")
	_check_interpolation(text, l)
	_emit({op = "line", speaker = speaker, text = text, tags = parsed[1], line = l.line})


func _choices(indent: int) -> void:
	var ins := {op = "choice", options = [], end = -1, line = _lines[_pos].line}
	_emit(ins)
	var jumps: Array[int] = []
	while _pos < _lines.size():
		var l := _lines[_pos]
		if l.indent != indent or not l.text.begins_with("- "):
			break
		var opt := {text = "", cond = "", ids = PackedStringArray(), once = false, tags = {}, id = "", to = -1}
		var text: String = l.text.substr(2)
		var m := _re("\\[if\\s+(.+?)\\]").search(text)
		if m:
			opt.cond = m.get_string(1).strip_edges()
			opt.ids = identifiers(opt.cond)
			_check_expr(opt.cond, l)
			text = text.replace(m.get_string(), "")
		if text.contains("[once]"):
			opt.once = true
			text = text.replace("[once]", "")
		var parsed := _split_tags(text.strip_edges())
		opt.text = parsed[0].strip_edges()
		opt.tags = parsed[1]
		opt.id = "%s/%s" % [_node, opt.text]
		_check_interpolation(opt.text, l)
		_pos += 1
		opt.to = _code.size()
		_child(indent)
		jumps.append(_emit({op = "jump", to = -1}))
		ins.options.append(opt)
	ins.end = _code.size()
	for j in jumps:
		_code[j].to = ins.end


func _if(indent: int) -> void:
	var jumps: Array[int] = []
	var l := _lines[_pos]
	var cond := _condition(l, "if")
	while true:
		var ins := {op = "if", expr = cond, ids = identifiers(cond), else_to = -1, line = l.line}
		_emit(ins)
		_pos += 1
		_child(indent)
		jumps.append(_emit({op = "jump", to = -1}))
		ins.else_to = _code.size()
		if _pos >= _lines.size() or _lines[_pos].indent != indent:
			break
		l = _lines[_pos]
		if _kw(l.text, "elif"):
			cond = _condition(l, "elif")
			continue
		if _kw(l.text, "else"):
			_pos += 1
			_child(indent)
		break
	for j in jumps:
		_code[j].to = _code.size()


func _condition(l: Dictionary, keyword: String) -> String:
	var cond: String = l.text.substr(keyword.length()).strip_edges().trim_suffix(":").strip_edges()
	if cond.is_empty():
		_error(l, "у «%s» нет условия" % keyword)
		return "false"
	_check_expr(cond, l)
	return cond


func _assignment(l: Dictionary) -> void:
	_pos += 1
	var m := _re("^set\\s+([A-Za-z_]\\w*)\\s*([-+*/]?=)\\s*(.+)$").search(l.text)
	if m == null:
		_error(l, "ожидается «set имя = выражение» (или +=, -=, *=, /=)")
		return
	var var_name := m.get_string(1)
	var op := m.get_string(2)
	var expr := m.get_string(3).strip_edges()
	if op != "=":
		expr = "%s %s (%s)" % [var_name, op[0], expr]
	_check_expr(expr, l)
	_emit({op = "set", name = var_name, expr = expr, ids = identifiers(expr), line = l.line})


## Хвостовые теги «#имя» / «#имя=значение» → [текст без тегов, {имя: значение|true}].
func _split_tags(text: String) -> Array:
	var tags := {}
	var re := _re("(?:^|\\s)#([^\\s#]+)\\s*$")
	while true:
		var m := re.search(text)
		if m == null:
			break
		var tag := m.get_string(1)
		var eq := tag.find("=")
		if eq > 0:
			tags[tag.substr(0, eq)] = tag.substr(eq + 1)
		else:
			tags[tag] = true
		text = text.substr(0, m.get_start()).strip_edges()
	return [text, tags]


## Синтаксис выражения проверяется сразу при загрузке, а не когда игрок дойдёт до строки.
func _check_expr(expr: String, l: Dictionary) -> void:
	var e := Expression.new()
	if e.parse(expr, identifiers(expr)) != OK:
		_error(l, "ошибка в выражении «%s»: %s" % [expr, e.get_error_text()])


func _check_interpolation(text: String, l: Dictionary) -> void:
	for m in _re("\\{([^{}]+)\\}").search_all(text):
		_check_expr(m.get_string(1), l)


func _emit(ins: Dictionary) -> int:
	_code.append(ins)
	return _code.size() - 1


func _error(l: Dictionary, msg: String) -> void:
	_errors.append("%s:%d: %s" % [_path, l.line, msg])
