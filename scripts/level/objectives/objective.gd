class_name Objective
extends Node

## Цель уровня — база. Кладётся дочерней нодой в LevelGoals.
##
## Жизненный цикл:
##   неактивна ──activate()──► активна (_on_activated: подписаться на мир)
##                                 │ set_progress / complete()
##                                 ▼
##                             выполнена ──► сигнал completed → LevelGoals
##
## Прогресс: progress / required (например, «убито 2/3») — для HUD и логов.
## optional — не нужна для завершения уровня (бонусная).
##
## Новая цель = скрипт `extends Objective`: в _on_activated() подписаться на нужные
## события и вызывать set_progress()/complete(). Готовые:
##   ObjectiveKill   — убить конкретные цели / всех из группы;
##   ObjectiveSignal — нода выпустила сигнал N раз (сломать, дёрнуть рычаг, подобрать…).

signal completed(objective: Objective)
signal progress_changed(objective: Objective)

@export_multiline var description := "" # текст для HUD: «Убей охранника»
@export var optional := false # бонусная: не блокирует завершение уровня

var is_active := false
var is_completed := false
var progress := 0
var required := 1


## Сделать цель активной (LevelGoals: сразу или по очереди).
func activate() -> void:
	if is_active or is_completed:
		return
	is_active = true
	_on_activated()


## Переопределяется наследниками: подписаться на события мира.
func _on_activated() -> void:
	pass


func set_progress(value: int) -> void:
	if is_completed:
		return
	progress = clampi(value, 0, required)
	progress_changed.emit(self)
	if progress >= required:
		complete()


func complete() -> void:
	if is_completed:
		return
	is_completed = true
	is_active = false
	completed.emit(self)


## «Убей охранника (1/2)» — для HUD/логов.
func get_text() -> String:
	if required > 1:
		return "%s (%d/%d)" % [description, progress, required]
	return description
