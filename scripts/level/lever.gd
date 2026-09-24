class_name Lever
extends Switch

## Рычаг: переключается ударом катаны. Ручка (нода Handle) наклоняется
## влево (выкл) / вправо (вкл). Искры — через дочерний HitEffect.

@export var angle_off := -35.0
@export var angle_on := 35.0

@onready var _handle: Node2D = $Handle


func set_on(on: bool) -> void:
	var changed := on != is_on
	super(on)
	if changed:
		Juice.shake(0.15)


func _update_visual(animated: bool) -> void:
	if _handle == null:
		return
	var target := deg_to_rad(angle_on if is_on else angle_off)
	if animated:
		create_tween().tween_property(_handle, "rotation", target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_handle.rotation = target
