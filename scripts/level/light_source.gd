class_name LightSource
extends PointLight2D

## Источник света: и картинка (PointLight2D), и игровое правило «здесь светло».
##
## Точка освещена, если она ближе radius к включённой лампе и (при blocked_by_walls)
## между ними нет стены. Враги используют это через Vision: игрок на свету виден
## издалека со всех сторон, в темноте — только в узком конусе перед врагом.
##
## set_active(on) — лампа может быть целью Switch: рычаг гасит свет → стелс-проход.
## Визуально свет полноценно работает, когда на уровне есть CanvasModulate (темнота) —
## без него лампа просто подсвечивает уже светлую картинку.

## Все лампы на сцене — без групп и поиска по дереву.
static var _all: Array[LightSource] = []
## Уровень освещён целиком (LevelLighting.fully_lit) — любая точка считается светлой.
static var level_fully_lit := false

@export var radius := 160.0:
	set(v):
		radius = v
		_apply_scale()
@export var blocked_by_walls := true
@export_flags_2d_physics var wall_mask := Layers.SOLID # что не пропускает свет (стены, двери)


func _enter_tree() -> void:
	_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


func _ready() -> void:
	if texture == null:
		texture = _make_texture()
	_apply_scale()


## Освещена ли точка хоть одной включённой лампой.
static func is_lit(point: Vector2) -> bool:
	if level_fully_lit:
		return true
	for l in _all:
		if l.lights(point):
			return true
	return false


## Освещает ли эта лампа точку.
func lights(point: Vector2) -> bool:
	if not enabled or not is_visible_in_tree():
		return false
	if global_position.distance_to(point) > radius:
		return false
	if not blocked_by_walls:
		return true
	var query := PhysicsRayQueryParameters2D.create(global_position, point, wall_mask)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Цель переключателя: включить/выключить свет.
func set_active(on: bool) -> void:
	enabled = on


## Радиус текстуры света совпадает с игровым radius.
func _apply_scale() -> void:
	if texture:
		texture_scale = radius * 2.0 / texture.get_width()


## Мягкое круглое пятно — чтобы лампа работала без своей текстуры.
static func _make_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t
