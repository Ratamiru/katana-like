class_name Turret
extends StaticBody2D

## Турель — стационарный враг, быстро стреляет очередями через BulletWorld.
## Не Fighter: не двигается и не падает, поэтому её можно ставить на пол, стену
## или потолок (поворачивай саму ноду — ствол целится в глобальных координатах).
##
## Цикл:
##   IDLE ──[игрок в range и виден]──► WARMUP ──[warmup]──► FIRING ⇄ (очередь / пауза)
##     ▲                                                     │
##     └──────────────[игрок пропал из вида]─────────────────┘
##   JAMMED — схвачена тенью (grab): не стреляет hold_time сек, потом IDLE.
##
## Ствол поворачивается к игроку с ограниченной скоростью turn_speed — от очереди
## можно уйти, если быстро сменить сторону. Стреляет, только когда ствол наведён
## (в пределах aim_tolerance). WARMUP — жёлтая вспышка, предупреждение.

signal died

enum State { IDLE, WARMUP, FIRING, JAMMED }
## BURST — очереди по burst_count с паузой burst_cooldown;
## CONTINUOUS — без перерыва, по пуле каждые fire_interval, пока видит игрока.
enum FireMode { BURST, CONTINUOUS }

@export var max_health := 10
@export var sight_range := 300.0 # игрок на свету — замечает так далеко во все стороны
@export var dark_sight_range := 180.0 # игрок в темноте — только так далеко…
@export var dark_cone_angle := 40.0 # …и только в конусе (град) вдоль ствола
@export var sight_mask := 1 # что загораживает обзор (стены)
@export var turn_speed := 180.0 # град/с поворота ствола
@export var aim_tolerance := 6.0 # град: стреляет, только если ствол наведён точнее
@export var warmup := 0.5 # сек предупреждения перед первой очередью
@export var fire_mode := FireMode.BURST
@export var fire_interval := 0.1 # CONTINUOUS: сек между пулями
@export var burst_count := 3
@export var burst_interval := 0.08 # сек между пулями в очереди
@export var burst_cooldown := 0.7 # сек между очередями
@export var bullet_speed := 500.0
@export var bullet_damage := 10
@export var bullet_hit_mask := 0b1000 # игрок
@export var spread_deg := 2.0

var state := State.IDLE
var health: int
var is_dead := false
var _target: Node2D
var _timer := 0.0
var _shots_left := 0
var _flash_tween: Tween

@onready var _barrel: Node2D = $Barrel
@onready var _muzzle: Node2D = $Barrel/Muzzle


func _ready() -> void:
	health = max_health
	add_to_group("enemy")


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D
		if _target == null:
			return

	_timer -= delta
	if state == State.JAMMED:
		if _timer <= 0.0:
			state = State.IDLE
		return

	# Заметить (из IDLE) — по правилам Vision (свет/конус вдоль ствола);
	# уже встревоженная турель ведёт цель по дальности и прямой видимости.
	var sees := _sees_target() if state != State.IDLE else Vision.detects(self, _barrel.global_position,
		Vector2.RIGHT.rotated(_barrel.global_rotation), _target, sight_range, dark_sight_range, dark_cone_angle, sight_mask)
	if get_tree().debug_collisions_hint:
		queue_redraw()
	if not sees:
		state = State.IDLE
		return

	_aim(delta)
	match state:
		State.IDLE:
			state = State.WARMUP
			_timer = warmup
			_flash(Color.YELLOW, warmup)
		State.WARMUP:
			if _timer <= 0.0:
				state = State.FIRING
				_shots_left = burst_count
				_timer = 0.0
		State.FIRING:
			if _timer <= 0.0 and _is_aimed():
				_fire()
				_shots_left -= 1
				if fire_mode == FireMode.CONTINUOUS:
					_timer = fire_interval
				elif _shots_left > 0:
					_timer = burst_interval
				else:
					_shots_left = burst_count
					_timer = burst_cooldown


## Отладка: зона обнаружения, пока турель не встревожена.
func _draw() -> void:
	if not get_tree().debug_collisions_hint or state != State.IDLE or _target == null or not is_instance_valid(_target):
		return
	Vision.draw_debug(self, _barrel.position, Vector2.RIGHT.rotated(_barrel.rotation),
		LightSource.is_lit(_target.global_position), sight_range, dark_sight_range, dark_cone_angle)


func _sees_target() -> bool:
	var from := _barrel.global_position
	var to := _target.global_position
	if from.distance_to(to) > sight_range:
		return false
	var query := PhysicsRayQueryParameters2D.create(from, to, sight_mask, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _aim(delta: float) -> void:
	var want := (_target.global_position - _barrel.global_position).angle()
	var diff := angle_difference(_barrel.global_rotation, want)
	var step := deg_to_rad(turn_speed) * delta
	_barrel.global_rotation += clampf(diff, -step, step)


func _is_aimed() -> bool:
	var want := (_target.global_position - _barrel.global_position).angle()
	return absf(angle_difference(_barrel.global_rotation, want)) <= deg_to_rad(aim_tolerance)


func _fire() -> void:
	var bullets := BulletWorld.current
	if bullets == null:
		return
	var dir := Vector2.RIGHT.rotated(_barrel.global_rotation + deg_to_rad(randf_range(-spread_deg, spread_deg)))
	bullets.spawn(_muzzle.global_position, dir * bullet_speed, bullet_damage, bullet_hit_mask)


## Схватить (тень): турель заклинивает на duration сек.
func grab(duration: float) -> bool:
	if is_dead:
		return false
	state = State.JAMMED
	_timer = duration
	_flash(Color(0.6, 0.3, 1.0), duration)
	return true


## Урон от катаны/пуль. Брони нет — урон проходит всегда.
func take_damage(amount: int, _from := global_position) -> bool:
	if is_dead:
		return false
	health -= amount
	_flash(Color.RED)
	if health <= 0:
		is_dead = true
		died.emit()
		queue_free()
	elif state == State.IDLE:
		state = State.WARMUP # ударили из-за угла — просыпается
		_timer = warmup
	return true


func _flash(color: Color, time := 0.1) -> void:
	if _flash_tween:
		_flash_tween.kill()
	modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, time)
