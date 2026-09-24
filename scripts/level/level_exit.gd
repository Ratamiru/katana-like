class_name LevelExit
extends Area2D

## Выход с уровня: игрок касается — LevelGoals.finish(), если цели выполнены.
## Пока цели не выполнены — «заперт» (цвет locked_color), касание ничего не делает.
## Если игрок уже стоит в выходе в момент выполнения последней цели — уровень кончается сразу.
## Без LevelGoals на уровне выход всегда открыт и просто перезапускает уровень.

@export var open_color := Color(0.3, 1.0, 0.5, 0.8)
@export var locked_color := Color(0.5, 0.5, 0.5, 0.4)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0b1000 # игрок (слой 4); тень на слое 0 выход не активирует
	monitoring = true
	body_entered.connect(_on_body_entered)
	if LevelGoals.current:
		LevelGoals.current.all_completed.connect(_on_all_completed)
	_update_visual()


func is_open() -> bool:
	return LevelGoals.current == null or LevelGoals.current.can_exit()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and is_open():
		_exit()


func _on_all_completed() -> void:
	_update_visual()
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			_exit()
			return


func _exit() -> void:
	if LevelGoals.current:
		LevelGoals.current.finish()
	else:
		ScreenFX.transition_to("")


func _update_visual() -> void:
	modulate = open_color if is_open() else locked_color
