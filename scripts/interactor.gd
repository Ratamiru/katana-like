class_name Interactor
extends Node2D

## Компонент «взаимодействовать с объектом рядом» (у тени; позже — у кого угодно).
##
## Интерактивный объект — ЛЮБАЯ нода с методом `interact(actor: Node) -> bool`
## (true — взаимодействие состоялось). Сейчас это Switch/Lever; потом терминалы,
## кнопки, ящики и т.п. — без правок здесь.
##
## try_interact(direction): круг radius со смещением reach в сторону direction
## (по умолчанию — к мыши), по маске mask (area и body), берёт ближайший объект
## с interact() и вызывает его. Проверка одноразовая (shape query), без Area2D.

signal interacted(target: Node)

@export var reach := 16.0
@export var radius := 24.0
@export_flags_2d_physics var mask := Layers.PROPS # где искать интерактивное (рычаги — Area2D на слое 5)
@export var cooldown := 0.2 # реальных сек между попытками

var _next_usec := 0


## Попытаться взаимодействовать. true — что-то сработало.
func try_interact(direction := Vector2.ZERO) -> bool:
	var now := Time.get_ticks_usec()
	if now < _next_usec:
		return false
	_next_usec = now + int(cooldown * 1_000_000.0)

	if direction == Vector2.ZERO:
		direction = get_local_mouse_position()
	var center := global_position + direction.normalized() * reach

	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	# Ближайший — первым: если он откажет (interact → false), пробуем следующий.
	var candidates: Array[Node2D] = []
	for r in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var c := r.collider as Node2D
		if c and c.has_method("interact") and c not in candidates:
			candidates.append(c)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	for c in candidates:
		if c.interact(get_parent()):
			interacted.emit(c)
			return true
	return false
