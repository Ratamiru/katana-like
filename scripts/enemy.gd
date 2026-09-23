extends Fighter

## Враг ближнего боя с примитивным AI:
## IDLE — стоит, пока не увидит игрока (в радиусе sight_range и без стен между ними);
## CHASE — бежит к игроку, перепрыгивает препятствия, спрыгивает с платформ, если игрок ниже,
##         и запрыгивает на платформу над собой, если игрок выше;
## ATTACK — в радиусе attack_range останавливается, замахивается (attack_windup) и бьёт;
## STUNNED — оглушён после клинча, стоит stun_time и не атакует.

enum State { IDLE, CHASE, ATTACK, STUNNED }

@export var sight_range := 250.0
@export var lose_range := 400.0 # дальше этого теряет интерес к игроку
@export var attack_range := 40.0
@export var attack_windup := 0.3 # сек замаха перед ударом — окно, чтобы игрок успел среагировать
@export var sight_mask := 1 # слои, которые загораживают обзор (сплошные стены)
@export var drop_height := 24.0 # насколько игрок должен быть ниже/выше, чтобы спрыгнуть/запрыгнуть на платформу
@export var clinch_window := 0.15 # последние сек замаха, которые тоже считаются ударом для клинча
@export var stun_time := 1.0 # длительность оглушения после клинча

var state := State.IDLE
var _target: Fighter
var _windup_left := 0.0
var _stun_left := 0.0


func _update_intent(delta: float) -> void:
	move_dir = 0.0
	if _target == null or not is_instance_valid(_target) or _target.is_dead:
		_target = get_tree().get_first_node_in_group("player") as Fighter
		state = State.IDLE
		if _target == null:
			return

	var to_target := _target.global_position - global_position
	var dist := to_target.length()

	match state:
		State.IDLE:
			if dist <= sight_range and _can_see(_target):
				state = State.CHASE
		State.CHASE:
			if dist > lose_range:
				state = State.IDLE
			elif dist <= attack_range and melee_attack.can_attack():
				state = State.ATTACK
				_windup_left = attack_windup
				_flash(Color.YELLOW, attack_windup)
			else:
				if absf(to_target.x) > attack_range * 0.5:
					move_dir = signf(to_target.x)
				if to_target.y > drop_height and is_on_drop_platform():
					# Игрок ниже, а мы на one-way платформе — спрыгиваем за ним.
					jump_requested = true
					drop_requested = true
				elif to_target.y < -drop_height and has_platform_above():
					# Игрок выше, а над нами досягаемая one-way платформа — запрыгиваем.
					jump_requested = true
				elif move_dir and is_on_floor() and is_on_wall():
					# Упёрся в стену на земле — пробуем перепрыгнуть.
					jump_requested = true
		State.ATTACK:
			_windup_left -= delta
			if _windup_left <= 0.0:
				melee_attack.attack(to_target)
				state = State.CHASE
		State.STUNNED:
			_stun_left -= delta
			if _stun_left <= 0.0:
				state = State.CHASE


func _can_see(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, sight_mask, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func is_attacking() -> bool:
	# Конец замаха тоже считается ударом — иначе поймать клинч почти невозможно.
	return super() or (state == State.ATTACK and _windup_left <= clinch_window)


func _on_clinch(other: Fighter) -> void:
	super(other)
	state = State.STUNNED
	_stun_left = stun_time
	_flash(Color(0.4, 0.6, 1.0), stun_time)


func take_damage(amount: int, from := global_position) -> void:
	super(amount, from)
	# Получил удар — сразу агрится, даже если не видел; замах прерывается.
	if not is_dead and (state == State.IDLE or state == State.ATTACK):
		state = State.CHASE
