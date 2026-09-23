extends Enemy

## Стрелок: тот же AI, что у Enemy, но вместо удара — выстрел пулей через BulletWorld.
## Держит дистанцию (подходит, только пока игрок дальше attack_range или не виден),
## стреляет, только если видит игрока. Замах = прицеливание (жёлтая вспышка).
## Клинча со стрелком не бывает — у него нет MeleeAttack, is_attacking() всегда false.

@export var bullet_speed := 400.0
@export var bullet_damage := 10
@export var bullet_hit_mask := 0b1000 # по кому бьют пули — игрок (слой 4)
@export var fire_cooldown := 1.2 # сек между выстрелами
@export var spread_deg := 3.0 # случайный разброс, чтобы не было идеальной точности

var _cooldown_left := 0.0


func _physics_process(delta: float) -> void:
	_cooldown_left -= delta
	super(delta)


func _can_start_attack() -> bool:
	return _cooldown_left <= 0.0 and _can_see(_target)


func _perform_attack(to_target: Vector2) -> void:
	_cooldown_left = fire_cooldown
	var bullets := BulletWorld.current
	if bullets == null or not _can_see(_target):
		return
	var dir := to_target.normalized().rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	bullets.spawn(global_position + dir * _half_height, dir * bullet_speed, bullet_damage, bullet_hit_mask)


func _should_approach(to_target: Vector2) -> bool:
	# Подходим, пока далеко или пока не видим игрока (за стеной).
	return absf(to_target.x) > attack_range or not _can_see(_target)


func is_attacking() -> bool:
	return false
