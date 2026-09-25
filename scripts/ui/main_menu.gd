extends Control

## Главное меню (стартовая сцена игры). Заглушка по виду, но рабочее.
##
## Две панели, видна одна:
##   Main  — «Продолжить» / «Загрузить» / «Выход»;
##   Load  — список уровней из LevelCatalog: открытые (Progress.is_unlocked)
##           кликабельны, закрытые — серые; «Назад» (или Esc) — обратно.
## «Продолжить» ведёт на Progress.get_continue_level() — без сохранения это
## первый уровень, поэтому кнопка подписана «Новая игра».
## Запуск уровня: Progress.mark_played(путь) → ScreenFX.transition_to(путь).
## Фокус ставится на первую кнопку панели — меню работает с клавиатуры/геймпада.

@onready var _main: Control = %Main
@onready var _load: Control = %Load
@onready var _continue: Button = %Continue
@onready var _load_btn: Button = %LoadButton
@onready var _quit: Button = %Quit
@onready var _levels: VBoxContainer = %Levels
@onready var _back: Button = %Back

var _starting := false # уровень уже грузится — игнорировать повторные нажатия


func _ready() -> void:
	get_tree().paused = false # на случай выхода в меню из паузы
	_continue.text = "Продолжить" if Progress.has_progress() else "Новая игра"
	_continue.pressed.connect(func() -> void: _start(Progress.get_continue_level()))
	_load_btn.pressed.connect(_show_load)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_back.pressed.connect(_show_main)
	_show_main()


func _unhandled_input(event: InputEvent) -> void:
	if _load.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_main()


func _show_main() -> void:
	_load.visible = false
	_main.visible = true
	_continue.grab_focus()


func _show_load() -> void:
	for c in _levels.get_children():
		c.queue_free()
	var first: Button = null
	for lvl: Dictionary in LevelCatalog.LEVELS:
		var path: String = lvl.path
		var b := Button.new()
		b.text = lvl.title
		b.disabled = not Progress.is_unlocked(path)
		if b.disabled:
			b.text += "  (закрыт)"
		else:
			b.pressed.connect(_start.bind(path))
			if first == null:
				first = b
		_levels.add_child(b)
	_main.visible = false
	_load.visible = true
	if first != null:
		first.grab_focus()
	else:
		_back.grab_focus()


func _start(path: String) -> void:
	if _starting or path == "":
		return
	_starting = true
	Progress.mark_played(path)
	ScreenFX.transition_to(path)
