class_name DialogueBalloon
extends CanvasLayer

## Стандартное окно диалога: панель внизу экрана, имя говорящего, текст с печатной машинкой
## (BBCode поддерживается), варианты выбора кнопками. Собирается кодом — сцена не нужна.
##
## Управление: ui_accept / use / ЛКМ — допечатать текст или дальше;
## варианты — мышью или стрелками + ui_accept.
##
## Свой вид: унаследоваться и переопределить _build() / _show_line(),
## либо сделать свою сцену с методом run(runner) и задать Dialogue.balloon_scene.

@export var chars_per_second := 50.0
@export var advance_actions: Array[StringName] = [&"ui_accept", &"use"]

var runner: DialogueRunner
var line: DialogueLine

var _panel: PanelContainer
var _speaker: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label
var _tween: Tween
var _accept_input := false


func _init() -> void:
	layer = 50
	_build()


func run(r: DialogueRunner) -> void:
	runner = r
	_advance()
	# Нажатие, открывшее диалог, не должно сразу его пролистать.
	await get_tree().process_frame
	_accept_input = true


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = 32
	_panel.offset_right = -32
	_panel.offset_top = -24
	_panel.offset_bottom = -24
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.07, 0.92)
	style.border_color = Color(0.55, 0.35, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	_speaker = Label.new()
	_speaker.add_theme_color_override("font_color", Color(0.8, 0.65, 1.0))
	_speaker.add_theme_font_size_override("font_size", 18)
	box.add_child(_speaker)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size.y = 48
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 18)
	box.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	box.add_child(_choices)

	_hint = Label.new()
	_hint.text = "▼"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate.a = 0.6
	box.add_child(_hint)


func _advance() -> void:
	var l := runner.next()
	if l: # null — диалог кончился, окно уберёт Dialogue
		_show_line(l)


func _show_line(l: DialogueLine) -> void:
	line = l
	_clear_choices()
	_hint.visible = false
	if l.text.is_empty(): # только выбор — оставляем на экране предыдущую реплику
		_on_typed()
		return
	_speaker.text = l.speaker
	_speaker.visible = not l.speaker.is_empty()
	_text.text = l.text
	_text.visible_characters = 0
	if _tween:
		_tween.kill()
	var count := _text.get_total_character_count()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(_text, "visible_characters", count, count / maxf(chars_per_second, 1.0))
	_tween.finished.connect(_on_typed)


func _clear_choices() -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func _on_typed() -> void:
	_text.visible_characters = -1
	_clear_choices()
	if not line.has_choices():
		_hint.visible = true
		return
	for i in line.choices.size():
		var b := Button.new()
		b.text = line.choices[i].text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_pick.bind(i))
		_choices.add_child(b)
	_focus_first_choice.call_deferred()


func _focus_first_choice() -> void:
	if _choices.get_child_count() > 0:
		_choices.get_child(0).grab_focus()


func _pick(index: int) -> void:
	runner.choose(index)
	_advance()


func _is_typing() -> bool:
	return _tween != null and _tween.is_running()


func _unhandled_input(event: InputEvent) -> void:
	if runner == null or line == null or not _accept_input or not _is_advance(event):
		return
	get_viewport().set_input_as_handled()
	if _is_typing():
		_tween.kill()
		_on_typed()
	elif not line.has_choices():
		_advance()


func _is_advance(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	for a in advance_actions:
		if InputMap.has_action(a) and event.is_action_pressed(a, false):
			return true
	return false
