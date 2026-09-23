class_name GrabAttack
extends Node2D

## Компонент захвата (у тени вместо MeleeAttack): на attack() ищет ближайшую
## цель в круге перед собой и вызывает у неё grab(hold_time).
## Цель сама решает, что значит «схвачена» (Enemy → состояние GRABBED).
## Проверка одноразовая (shape query в момент нажатия), без Area2D.

signal grabbed(target: Node)
signal missed

@export var reach := 16.0 # смещение центра круга в сторону удара
@export var radius := 22.0
@export var grab_mask := 0b0100 # враги (слой 3)
@export var hold_time := 2.0 # сколько держим цель (игровое время)
@export var cooldown := 0.25 # реальных сек между попытками, чтобы не спамить

var _next_grab_usec := 0 # реальное время, раньше которого нельзя снова хватать


## Попытка захвата в направлении direction (локально). Без аргумента — к мыши.
func attack(direction := Vector2.ZERO) -> bool:
	var now := Time.get_ticks_usec()
	if now < _next_grab_usec:
		return false
	_next_grab_usec = now + int(cooldown * 1_000_000.0)

	if direction == Vector2.ZERO:
		direction = get_local_mouse_position()
	var center := global_position + direction.normalized() * reach

	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = grab_mask
	var results := get_world_2d().direct_space_state.intersect_shape(query, 8)

	# Ближайшая цель, которую можно схватить.
	var best: Node2D
	var best_d := INF
	for r in results:
		var c := r.collider as Node2D
		if c == null or not c.has_method("grab"):
			continue
		var d := c.global_position.distance_squared_to(center)
		if d < best_d:
			best_d = d
			best = c
	if best and best.grab(hold_time):
		grabbed.emit(best)
		return true
	missed.emit()
	return false
