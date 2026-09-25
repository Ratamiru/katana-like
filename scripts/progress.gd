extends Node

## Progress — прогресс игрока. Autoload, доступен как `Progress`.
##
## Хранит в user://progress.cfg (ConfigFile):
##   [progress] unlocked — открытые уровни (пути сцен);
##              last     — уровень для «Продолжить» (самый дальний достигнутый).
## Первый уровень каталога (LevelCatalog) открыт всегда, даже без файла.
## Файла нет или он битый — начинаем с чистого прогресса, без ошибок.
## Любое изменение сразу пишется на диск.
##
## Кто пишет: LevelGoals.finish() → complete_level(текущий, следующий);
## главное меню при запуске уровня → mark_played(путь).
##
## Ещё здесь Esc (действие `menu`) во время уровня — возврат в главное меню.
## process_mode обычный: пока диалог держит паузу дерева, Esc не срабатывает
## (иначе ушли бы из меню с поставленной на паузу игрой).

const SAVE_PATH := "user://progress.cfg"
const SECTION := "progress"
const MENU_SCENE := "res://ui/main_menu.tscn"

var _unlocked: PackedStringArray = []
var _last := ""


func _ready() -> void:
	_load()


# ── API ──

func is_unlocked(path: String) -> bool:
	return path == LevelCatalog.first_path() or _unlocked.has(path)


## Открыть уровень (без смены цели «Продолжить»).
func unlock(path: String) -> void:
	if path == "" or _unlocked.has(path):
		return
	_unlocked.append(path)
	_save()


## Уровень запущен: открыть его и сделать целью «Продолжить».
func mark_played(path: String) -> void:
	if path == "":
		return
	if not _unlocked.has(path):
		_unlocked.append(path)
	_last = path
	_save()


## Уровень пройден: открыть следующий и сделать его целью «Продолжить».
## next_path пусто (уровень перезапускается) — просто отметить текущий.
func complete_level(path: String, next_path: String) -> void:
	if path != "" and not _unlocked.has(path):
		_unlocked.append(path)
	mark_played(next_path if next_path != "" else path) # он же сохраняет


## Куда ведёт «Продолжить»: последний достигнутый уровень, если он ещё
## есть в каталоге и открыт; иначе — первый уровень.
func get_continue_level() -> String:
	if _last != "" and LevelCatalog.has(_last) and is_unlocked(_last):
		return _last
	return LevelCatalog.first_path()


## Есть ли вообще сохранённый прогресс (для подписи кнопки).
func has_progress() -> bool:
	return _last != ""


## Стереть прогресс (и файл).
func reset_progress() -> void:
	_unlocked = PackedStringArray()
	_last = ""
	_save()


## В главное меню (через затемнение).
func go_to_menu() -> void:
	PlayerPawn.possess(null)
	Juice.reset()
	ScreenFX.transition_to(MENU_SCENE)


# ── Esc во время уровня ──

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("menu"):
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == MENU_SCENE:
		return
	get_viewport().set_input_as_handled()
	go_to_menu()


# ── Диск ──

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return # файла нет или битый — чистый прогресс
	var u: Variant = cfg.get_value(SECTION, "unlocked", PackedStringArray())
	if u is PackedStringArray:
		_unlocked = u
	elif u is Array:
		_unlocked = PackedStringArray(u)
	var l: Variant = cfg.get_value(SECTION, "last", "")
	_last = l if l is String else ""


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "unlocked", _unlocked)
	cfg.set_value(SECTION, "last", _last)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Progress: не удалось сохранить %s (%s)" % [SAVE_PATH, error_string(err)])
