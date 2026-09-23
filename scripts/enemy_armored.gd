extends Enemy

## Бронированный враг: спереди (со стороны facing) урон не проходит — блок,
## искры и отдача атакующему. Уязвим сзади. Сам всегда разворачивается к игроку
## (Enemy), поэтому зайти за спину можно, только пока он не поворачивается:
## схвачен тенью (GRABBED) или оглушён клинчем (STUNNED).

@export var shield_offset := 10.0 # смещение ноды Shield от центра в сторону facing

@onready var _shield: Node2D = get_node_or_null("Shield")


func _physics_process(delta: float) -> void:
	super(delta)
	if _shield:
		_shield.position.x = facing * shield_offset


## Удар спереди? from — позиция атакующего/пули.
func is_front(from: Vector2) -> bool:
	var side := signf(from.x - global_position.x)
	return side == facing


func take_damage(amount: int, from := global_position) -> bool:
	if not is_dead and is_front(from):
		_flash(Color(1.5, 1.5, 1.5), 0.05)
		# Блок не прерывает замах и не агрит сильнее — просто «дзынь».
		if state == State.IDLE:
			state = State.CHASE
		return false
	return super(amount, from)
