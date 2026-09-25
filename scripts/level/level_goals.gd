class_name LevelGoals
extends Node

## Цели уровня и его завершение. Одна нода на уровень (в сцене уровня),
## доступ отовсюду: LevelGoals.current.
##
## Цели — дочерние ноды типа Objective. Сколько их, какие и в каком порядке —
## собирается в редакторе:
##   order = PARALLEL   — все обязательные активны сразу, выполняй в любом порядке;
##   order = SEQUENTIAL — по одной сверху вниз (необязательные активны сразу).
##
## Когда выполнены все обязательные (optional = false) → all_completed, дальше finish_mode:
##   EXIT — открываются выходы LevelExit, уровень кончается, когда игрок коснётся выхода;
##   AUTO — уровень кончается сам через auto_finish_delay.
## Уровень без обязательных целей считается выполненным сразу (выход открыт).
##
## finish(): управление отбирается (possess(null)), время нормализуется,
## ScreenFX затемняет экран и грузит next_level (пусто — перезапуск текущего),
## затем проявляет новый уровень.

signal objective_completed(objective: Objective)
signal all_completed
signal level_finished

enum Order { PARALLEL, SEQUENTIAL }
enum FinishMode { EXIT, AUTO }

static var current: LevelGoals

@export var order := Order.PARALLEL
@export var finish_mode := FinishMode.EXIT
@export var auto_finish_delay := 1.0 # AUTO: сек после последней цели до затемнения
@export_file("*.tscn") var next_level := "" # пусто — перезапустить текущий уровень

var objectives: Array[Objective] = []
var is_all_completed := false
var _finished := false


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	for c in get_children():
		if c is Objective:
			objectives.append(c)
			c.completed.connect(_on_objective_completed)
	_activate_objectives()
	_check_all.call_deferred() # уровень без целей — выполнен сразу (после _ready выходов)


## Активные и ещё не выполненные цели — для HUD.
func get_active() -> Array[Objective]:
	var out: Array[Objective] = []
	for o in objectives:
		if o.is_active:
			out.append(o)
	return out


func can_exit() -> bool:
	return is_all_completed


## Завершить уровень: затемнение и переход на next_level.
func finish() -> void:
	if _finished:
		return
	_finished = true
	level_finished.emit()
	PlayerPawn.possess(null) # никто не получает инпут
	Juice.reset()
	Progress.complete_level(get_tree().current_scene.scene_file_path, next_level)
	ScreenFX.transition_to(next_level)


func _activate_objectives() -> void:
	for o in objectives:
		if o.optional or order == Order.PARALLEL:
			o.activate()
	if order == Order.SEQUENTIAL:
		_activate_next_required()


func _activate_next_required() -> void:
	for o in objectives:
		if not o.optional and not o.is_completed:
			o.activate()
			return


func _on_objective_completed(o: Objective) -> void:
	print("Цель выполнена: ", o.get_text())
	objective_completed.emit(o)
	if order == Order.SEQUENTIAL and not o.optional:
		_activate_next_required()
	_check_all()


func _check_all() -> void:
	if is_all_completed or _finished:
		return
	for o in objectives:
		if not o.optional and not o.is_completed:
			return
	is_all_completed = true
	print("Все цели выполнены")
	all_completed.emit()
	if finish_mode == FinishMode.AUTO:
		await get_tree().create_timer(auto_finish_delay).timeout
		if is_instance_valid(self):
			finish()
