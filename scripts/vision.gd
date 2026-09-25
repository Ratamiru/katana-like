class_name Vision
extends RefCounted

## Правила зрения врагов (общие для Enemy и Turret).
##
## Цель ОБНАРУЖЕНА, если между глазом и целью нет стены (sight_mask) и:
##   • цель на свету (LightSource.is_lit)  — дальность sight_range, во все стороны;
##   • цель в темноте                       — дальность dark_range и только в конусе
##                                            dark_cone_deg вокруг направления взгляда.
## Поэтому в темноте можно проскочить над головой или за спиной врага.
## Конус действует только на обнаружение: уже поднявший тревогу враг ведёт цель как раньше.


static func detects(observer: CollisionObject2D, eye: Vector2, look_dir: Vector2, target: Node2D,
		sight_range: float, dark_range: float, dark_cone_deg: float, sight_mask: int) -> bool:
	var to := target.global_position - eye
	var dist := to.length()
	if LightSource.is_lit(target.global_position):
		if dist > sight_range:
			return false
	else:
		if dist > dark_range:
			return false
		if dist > 0.001 and absf(look_dir.angle_to(to)) > deg_to_rad(dark_cone_deg) * 0.5:
			return false
	return has_los(observer, eye, target.global_position, sight_mask)


static func has_los(observer: CollisionObject2D, from: Vector2, to: Vector2, mask: int) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, mask, [observer.get_rid()])
	return observer.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Отладка (Debug → Visible Collision Shapes): зона обнаружения в локальных координатах ci.
## lit — цель сейчас на свету (рисуется круг), иначе — конус.
static func draw_debug(ci: CanvasItem, eye: Vector2, look_dir: Vector2, lit: bool,
		sight_range: float, dark_range: float, dark_cone_deg: float) -> void:
	if lit:
		ci.draw_arc(eye, sight_range, 0.0, TAU, 48, Color(1, 0.9, 0.3, 0.35), 1.0)
		return
	var half := deg_to_rad(dark_cone_deg) * 0.5
	var pts := PackedVector2Array([eye])
	for i in 13:
		pts.append(eye + look_dir.rotated(lerpf(-half, half, i / 12.0)) * dark_range)
	ci.draw_colored_polygon(pts, Color(0.4, 0.6, 1.0, 0.15))
	pts.append(eye)
	ci.draw_polyline(pts, Color(0.4, 0.6, 1.0, 0.5), 1.0)
