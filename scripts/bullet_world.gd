class_name BulletWorld
extends Node2D

## Все пули уровня в одной ноде — без отдельной ноды на каждую пулю.
##
## ── Как устроено ──
##
## Данные хранятся «структурой массивов» (SoA): i-я пуля — это i-е элементы
## всех Packed*Array ниже. Packed-массивы лежат в памяти сплошным куском,
## их обход дешёвый, а создание пули — это просто append, без add_child,
## без _ready/_process на каждую пулю и без нагрузки на дерево сцены.
##
## Удаление — swap-remove: на место удаляемой пули копируется последняя,
## массивы укорачиваются на 1. Порядок пуль не важен, зато удаление O(1).
## Поэтому снаружи НЕЛЬЗЯ хранить индекс пули между кадрами — он может смениться.
##
## Кадр (_physics_process):
##   1. аффекторы (affect_bullets) — внешние эффекты меняют скорость/цели пуль;
##   2. для каждой пули: время жизни, луч from→to за этот кадр (не проскочит
##      сквозь тонкую стену на большой скорости), попадание → take_damage / удаление;
##   3. queue_redraw() — все пули рисуются одним _draw().
##
## ── Аффекторы — задел под отражение, магниты, замедляющие поля и т.п. ──
##
## Любой объект с методом `affect_bullets(bullets: BulletWorld, delta: float)`
## регистрируется через add_affector() и каждый кадр получает доступ к пулям:
## ищет нужные (query_circle / query_rect) и меняет их через set_bullet_velocity /
## set_bullet_hit_mask / set_bullet_color. Пример — отражение катаной в MeleeAttack.
## Пример магнита:
##
##   func affect_bullets(b: BulletWorld, delta: float) -> void:
##       for i in b.query_circle(global_position, 100.0):
##           var to_me := (global_position - b.get_bullet_position(i)).normalized()
##           b.set_bullet_velocity(i, b.get_bullet_velocity(i) + to_me * 800.0 * delta)
##
## Доступ из любого скрипта: BulletWorld.current (нода должна быть в сцене уровня).

static var current: BulletWorld

@export_flags_2d_physics var world_mask := Layers.SOLID # что останавливает пули: стены и двери/окна (one-way платформы — нет)
@export var max_bullets := 2048
@export var lifetime := 3.0 # сек, потом пуля исчезает
@export var radius := 2.5 # для отрисовки и проверок аффекторов
@export var trail := 0.02 # длина хвоста = скорость * trail
@export var wall_effect: PackedScene # эффект при попадании в стену/объект без реакций (искры)

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _damage := PackedInt32Array()
var _hit_mask := PackedInt32Array() # кого пуля может ранить (физ. слои целей)
var _color := PackedColorArray()

var _affectors: Array[Object] = []
var _query := PhysicsRayQueryParameters2D.new() # один объект на все лучи — без аллокаций в цикле


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	z_index = 10
	# Пули рисуются без освещения: в тёмных зонах их должно быть видно всегда.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


# ── Создание ──

## Выпустить пулю. hit_mask — физ. слои, по которым она наносит урон.
func spawn(pos: Vector2, vel: Vector2, damage: int, hit_mask: int, color := Color.ORANGE) -> void:
	if _pos.size() >= max_bullets:
		return
	_pos.append(pos)
	_vel.append(vel)
	_life.append(lifetime)
	_damage.append(damage)
	_hit_mask.append(hit_mask)
	_color.append(color)


# ── API для аффекторов (индексы валидны только в пределах текущего кадра) ──

func add_affector(a: Object) -> void:
	if a not in _affectors:
		_affectors.append(a)


func remove_affector(a: Object) -> void:
	_affectors.erase(a)


func count() -> int:
	return _pos.size()


func get_bullet_position(i: int) -> Vector2:
	return _pos[i]


func get_bullet_velocity(i: int) -> Vector2:
	return _vel[i]


func set_bullet_velocity(i: int, v: Vector2) -> void:
	_vel[i] = v


func get_bullet_hit_mask(i: int) -> int:
	return _hit_mask[i]


func set_bullet_hit_mask(i: int, mask: int) -> void:
	_hit_mask[i] = mask


func set_bullet_color(i: int, c: Color) -> void:
	_color[i] = c


## Индексы пуль в круге.
func query_circle(center: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r2 := (r + radius) * (r + radius)
	for i in _pos.size():
		if _pos[i].distance_squared_to(center) <= r2:
			out.append(i)
	return out


## Индексы пуль в прямоугольнике size, центрированном в xform (с учётом поворота).
func query_rect(xform: Transform2D, size: Vector2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var inv := xform.affine_inverse()
	var half := size * 0.5 + Vector2(radius, radius)
	for i in _pos.size():
		var p := inv * _pos[i]
		if absf(p.x) <= half.x and absf(p.y) <= half.y:
			out.append(i)
	return out


func clear() -> void:
	_pos.clear()
	_vel.clear()
	_life.clear()
	_damage.clear()
	_hit_mask.clear()
	_color.clear()


# ── Симуляция ──

func _physics_process(delta: float) -> void:
	for a in _affectors.duplicate():
		if is_instance_valid(a):
			a.affect_bullets(self, delta)
		else:
			_affectors.erase(a)

	var space := get_world_2d().direct_space_state
	var i := _pos.size() - 1
	# Идём с конца: swap-remove переносит последнюю (уже обработанную) пулю на место i.
	while i >= 0:
		_life[i] -= delta
		if _life[i] <= 0.0:
			_remove(i)
			i -= 1
			continue

		var from := _pos[i]
		var to := from + _vel[i] * delta
		_query.from = from
		_query.to = to
		_query.collision_mask = world_mask | _hit_mask[i]
		var hit := space.intersect_ray(_query)
		if hit.is_empty():
			_pos[i] = to
		else:
			var target := hit.collider as Node
			var dir := _vel[i].normalized()
			var blocked := false
			if target and target.has_method("take_damage"):
				# from для отбрасывания — точка чуть позади пули.
				blocked = not target.take_damage(_damage[i], hit.position - dir * 8.0)
			if HitReaction.has_reactions(target):
				var info := HitInfo.make(null, target, hit.position, dir, _damage[i], &"bullet")
				info.blocked = blocked
				info.killed = target.get("is_dead") == true
				HitReaction.dispatch(target, info)
			else:
				# Стена или объект без своих реакций — искры по нормали поверхности.
				Juice.spawn_effect(wall_effect, hit.position, hit.normal)
			_remove(i)
		i -= 1

	queue_redraw()


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_life[i] = _life[last]
		_damage[i] = _damage[last]
		_hit_mask[i] = _hit_mask[last]
		_color[i] = _color[last]
	_pos.resize(last)
	_vel.resize(last)
	_life.resize(last)
	_damage.resize(last)
	_hit_mask.resize(last)
	_color.resize(last)


func _draw() -> void:
	# Нода стоит в (0,0) мира без поворота, так что глобальные координаты = локальные.
	for i in _pos.size():
		draw_line(_pos[i], _pos[i] - _vel[i] * trail, _color[i], radius)
		draw_circle(_pos[i], radius, _color[i])
