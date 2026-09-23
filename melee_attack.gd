class_name MeleeAttack
extends Node2D

## Компонент ближней атаки в сторону мыши (катана/меч).
## Добавь как child-ноду к персонажу и вызывай attack() по инпуту.
## Хитбокс — Area2D, создаётся один раз в _ready(), а не пересоздаётся
## на каждую атаку — просто переставляется/поворачивается и включается.

@export var reach := 24.0                   # смещение хитбокса вперёд от персонажа ("это размер" на скетче)
@export var hitbox_size := Vector2(36, 14)  # размер прямоугольника удара
@export var damage := 10
@export var active_time := 0.12             # сколько сек хитбокс реально может задеть цель
@export var cooldown := 0.3                 # минимальный интервал между атаками
@export var hit_mask := 0b0100              # физ. слои целей: 0b0100 — враги (слой 3), 0b1000 — игрок (слой 4)
@export var deflect_bullets := false        # отбивать пули BulletWorld, летящие во владельца
@export var deflect_speed_mult := 1.5       # во сколько раз быстрее летит отбитая пуля
@export var deflect_color := Color.CYAN
@export var deflect_padding := Vector2(24, 24) # насколько зона отражения больше хитбокса — чем больше, тем проще отбить
@export var deflect_effect: PackedScene      # эффект в точке отбитой пули (искры)

signal hit_landed(target: Node)
signal clinched(target: Node)
signal deflected # отбита хотя бы одна пуля за кадр

var _can_attack := true
var _cancelled := false # удар погашен клинчем — хитбокс больше никого не бьёт
var _already_hit: Array[Node] = []  # чтобы один взмах не бил одну цель дважды

@onready var _hitbox: Area2D = _make_hitbox()


func _make_hitbox() -> Area2D:
	var area := Area2D.new()
	area.monitoring = false
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = hit_mask

	var shape := RectangleShape2D.new()
	shape.size = hitbox_size

	var coll := CollisionShape2D.new()
	coll.shape = shape

	area.add_child(coll)
	add_child(area)

	area.area_entered.connect(_try_hit)
	area.body_entered.connect(_try_hit)

	return area


func can_attack() -> bool:
	return _can_attack


## Хитбокс сейчас активен (идёт удар).
func is_active() -> bool:
	return _hitbox.monitoring and not _cancelled


## Погасить текущий удар (клинч). Кулдаун продолжает идти как обычно.
func cancel() -> void:
	_cancelled = true
	_hitbox.set_deferred("monitoring", false)


## Удар в направлении direction (локально). Без аргумента — в сторону мыши (для игрока).
func attack(direction := Vector2.ZERO) -> void:
	if not _can_attack:
		return
	_can_attack = false

	if direction == Vector2.ZERO:
		direction = get_local_mouse_position()
	var angle_rad := direction.angle()
	_hitbox.rotation = angle_rad
	_hitbox.position = Vector2(reach, 0).rotated(angle_rad)

	_already_hit.clear()
	_cancelled = false
	_hitbox.monitoring = true
	var bullets := BulletWorld.current
	if deflect_bullets and bullets:
		bullets.add_affector(self)

	await get_tree().create_timer(active_time).timeout
	if not is_instance_valid(self):
		return
	_hitbox.monitoring = false
	if is_instance_valid(bullets):
		bullets.remove_affector(self)

	var rest: float = max(cooldown - active_time, 0.0)
	if rest > 0.0:
		await get_tree().create_timer(rest).timeout
	if not is_instance_valid(self):
		return
	_can_attack = true


## Аффектор BulletWorld: пока удар активен, пули в хитбоксе, летящие во владельца,
## разворачиваются по направлению удара и начинают бить по hit_mask (как в Katana Zero).
func affect_bullets(bullets: BulletWorld, _delta: float) -> void:
	if not is_active():
		return
	var owner_layer: int = get_parent().collision_layer
	var dir := Vector2.RIGHT.rotated(_hitbox.global_rotation)
	var any := false
	for i in bullets.query_rect(_hitbox.global_transform, hitbox_size + deflect_padding):
		if (bullets.get_bullet_hit_mask(i) & owner_layer) == 0:
			continue # пуля летит не в нас (или уже отбита)
		bullets.set_bullet_velocity(i, dir * bullets.get_bullet_velocity(i).length() * deflect_speed_mult)
		bullets.set_bullet_hit_mask(i, hit_mask)
		bullets.set_bullet_color(i, deflect_color)
		Juice.spawn_effect(deflect_effect, bullets.get_bullet_position(i), dir)
		any = true
	if any:
		deflected.emit()


func _try_hit(target: Node) -> void:
	var attacker := get_parent()
	if _cancelled or target == self or target == attacker or target in _already_hit:
		return
	_already_hit.append(target)

	# Цель тоже бьёт в этот момент — клинч вместо урона.
	if target.has_method("is_attacking") and target.is_attacking() and attacker.has_method("clinch"):
		attacker.clinch(target)
		clinched.emit(target)
		return

	var dir := Vector2.RIGHT.rotated(_hitbox.global_rotation)
	var hit_pos: Vector2 = (target as Node2D).global_position if target is Node2D else _hitbox.global_position
	var hit := HitInfo.make(attacker, target, hit_pos, dir, damage, &"melee")
	if target.has_method("take_damage"):
		target.take_damage(damage, global_position)
	hit.killed = target.get("is_dead") == true
	# Реакции цели (кровь, искры, свои реакции пропов). Работает и для целей без take_damage.
	HitReaction.dispatch(target, hit)

	hit_landed.emit(target)
