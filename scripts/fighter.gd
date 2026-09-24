class_name Fighter
extends CharacterBody2D

## Общий «скелет» бойца: физика движения (бег, прыжок, спрыгивание с платформ,
## скольжение по стене, отпрыжка), здоровье и атака через MeleeAttack.
## Наследники не читают физику сами — они только заполняют «намерения»
## (move_dir / jump_requested / drop_requested) в _update_intent().
## Игрок берёт их из инпута, враг — из AI.

signal damaged(amount: int)
signal died
signal clinched(other: Fighter)

const PLATFORM_LAYER := 2 # Платформу под которые можно проваливаться, обычные на первом
const DROP_THROUGH_TIME := 0.25
const FLOOR_PROBE := 20.0 # длина луча вниз от центра для проверки «стою на платформе»

@export var max_health := 30
@export var speed := 300.0
@export var jump_velocity := -400.0
@export var wall_jump_velocity := Vector2(350.0, -400.0) # x — отталкивание от стены, y — прыжок вверх
@export var wall_slide_max_speed := 100.0 # максимальная скорость сползания по стене
@export var wall_jump_lock_time := 0.15 # сек, в течение которых move_dir игнорируется после отпрыжки
@export var knockback := Vector2(250.0, -150.0) # отбрасывание при получении удара
@export var knockback_time := 0.2 # сек без управления после удара
@export var clinch_knockback := Vector2(300.0, -120.0) # отбрасывание обоих при клинче
@export var clinch_effect: PackedScene # эффект между бойцами при клинче (искры); берётся у любого из двух
## Жить в реальном времени: движение не замедляется Engine.time_scale (тень во время замедления).
@export var unscaled_time := false

@export_group("Lunge")
## Выпад при ударе (как в Katana Zero): импульс в сторону удара + короткая блокировка управления.
## На земле — всегда, в воздухе — один раз до приземления. 0 — выпада нет.
@export var lunge_speed := 0.0
@export var lunge_vertical_mult := 0.8 # доля вертикальной составляющей: удар вверх подбрасывает слабее, чем толкает вбок
@export var lunge_time := 0.12 # сек, пока move_dir не гасит выпад
@export_group("")

# Намерения на текущий кадр — выставляются в _update_intent().
var move_dir := 0.0
var jump_requested := false
var drop_requested := false

var facing := 1.0 # куда смотрит боец: 1 — вправо, -1 — влево. Обновляется по move_dir; враги — по цели

var health: int
var is_dead := false
var _control_lock := 0.0 # пока > 0, move_dir игнорируется (отпрыжка, отбрасывание, выпад)
var _air_lunge_used := false # выпад в воздухе уже был — следующий только после приземления
var _flash_tween: Tween
@onready var _half_height: float = ($Collision as CollisionShape2D).shape.get_rect().size.y * 0.5

@onready var melee_attack: MeleeAttack = get_node_or_null("MeleeAttack") # может не быть (стрелок)


func _ready() -> void:
	health = max_health


## Переопределяется наследниками: выставить move_dir / jump_requested / drop_requested.
func _update_intent(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# unscaled_time: delta и скорость пересчитываются в реальное время.
	# Гравитация/таймеры считаются по реальному delta, а move_and_slide (который
	# внутри берёт замедленный physics delta) получает скорость × k.
	var k := 1.0
	if unscaled_time and Engine.time_scale > 0.0:
		k = 1.0 / Engine.time_scale
	delta *= k
	_update_intent(delta)
	if move_dir:
		facing = signf(move_dir)

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		_air_lunge_used = false
	# Скольжение по стене: персонаж прижат к стене в воздухе.
	var on_wall := is_on_wall_only()
	if on_wall and velocity.y > wall_slide_max_speed:
		velocity.y = wall_slide_max_speed

	if jump_requested:
		if is_on_floor() and drop_requested:
			_drop_through()
		elif is_on_floor():
			velocity.y = jump_velocity
		elif on_wall:
			velocity = Vector2(get_wall_normal().x * wall_jump_velocity.x, wall_jump_velocity.y)
			_control_lock = wall_jump_lock_time
	jump_requested = false

	if _control_lock > 0.0:
		# Не даём move_dir сразу погасить отпрыжку/отбрасывание.
		_control_lock -= delta
	elif move_dir:
		velocity.x = move_dir * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
	velocity *= k
	move_and_slide()
	velocity /= k


func _drop_through() -> void:
	set_collision_mask_value(PLATFORM_LAYER, false)
	await get_tree().create_timer(DROP_THROUGH_TIME).timeout
	if is_instance_valid(self):
		set_collision_mask_value(PLATFORM_LAYER, true)


## Стоит ли на one-way платформе (с которой можно спрыгнуть).
func is_on_drop_platform() -> bool:
	if not is_on_floor():
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, FLOOR_PROBE), 1 << (PLATFORM_LAYER - 1), [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Макс. высота прыжка с места (из jump_velocity и гравитации).
func get_jump_height() -> float:
	return jump_velocity * jump_velocity / (2.0 * get_gravity().y)


## Есть ли над головой one-way платформа, на которую можно запрыгнуть с места.
## Луч идёт СВЕРХУ ВНИЗ: от макс. высоты прыжка ног до чуть выше ног —
## так он попадает в верхнюю грань платформы, на которую нужно встать.
func has_platform_above() -> bool:
	if not is_on_floor():
		return false
	var feet_y := global_position.y + _half_height
	var from := Vector2(global_position.x, feet_y - get_jump_height() * 0.9) # 0.9 — запас, чтобы точно допрыгнуть
	var to := Vector2(global_position.x, feet_y - 4.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1 << (PLATFORM_LAYER - 1), [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Отбросить от точки from (по X — в противоположную сторону, по Y — как в force).
func apply_knockback(from: Vector2, force: Vector2, lock_time := knockback_time) -> void:
	var dir := signf(global_position.x - from.x)
	if dir == 0.0:
		dir = 1.0
	velocity = Vector2(dir * force.x, force.y)
	_control_lock = maxf(_control_lock, lock_time)


## Выпад в направлении dir (обычно — направление удара). true — если выпад был.
## В воздухе срабатывает один раз до приземления (иначе удары в воздухе = полёт).
func lunge(dir: Vector2) -> bool:
	if lunge_speed <= 0.0 or dir == Vector2.ZERO:
		return false
	if not is_on_floor():
		if _air_lunge_used:
			return false
		_air_lunge_used = true
	var d := dir.normalized()
	velocity = Vector2(d.x, d.y * lunge_vertical_mult) * lunge_speed
	_control_lock = maxf(_control_lock, lunge_time)
	return true


## Идёт ли сейчас удар, который может столкнуться с чужим (клинч).
func is_attacking() -> bool:
	return melee_attack != null and melee_attack.is_active()


## Клинч: оба удара гасятся, урона нет, бойцов расталкивает.
## Вызывается MeleeAttack атакующего, когда его удар попал в атакующую цель.
func clinch(other: Fighter) -> void:
	if melee_attack:
		melee_attack.cancel()
	if other.melee_attack:
		other.melee_attack.cancel()
	var fx := clinch_effect if clinch_effect else other.clinch_effect
	var mid := (global_position + other.global_position) * 0.5
	Juice.spawn_effect(fx, mid, Vector2.UP)
	_on_clinch(other)
	other._on_clinch(self)


## Переопределяется наследниками (враг — оглушение).
func _on_clinch(other: Fighter) -> void:
	apply_knockback(other.global_position, clinch_knockback)
	_flash(Color(2, 2, 2))
	clinched.emit(other)


## Вызывается хитбоксом MeleeAttack и пулями. from — позиция атакующего (для отбрасывания).
## Возвращает true, если урон прошёл; false — если заблокирован (броня) или цель уже мертва.
func take_damage(amount: int, from := global_position) -> bool:
	if is_dead:
		return false
	health -= amount
	damaged.emit(amount)
	_flash(Color.RED)
	apply_knockback(from, knockback)
	if health <= 0:
		is_dead = true
		died.emit()
		_die()
	return true


## Переопределяется наследниками.
func _die() -> void:
	queue_free()


## Окрасить бойца и плавно вернуть цвет. Новая вспышка перебивает предыдущую.
func _flash(color: Color, time := 0.1) -> void:
	if _flash_tween:
		_flash_tween.kill()
	modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, time)
