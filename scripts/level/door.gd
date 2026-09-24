class_name Door
extends AnimatableBody2D

## Дверь — пример управляемого объекта: всё, у чего есть set_active(on),
## можно повесить в targets переключателя.
## Активна → открыта: сдвигается на open_offset. inverted — наоборот.
## AnimatableBody2D на слое 1 (мир): держит игрока и врагов, закрывает обзор
## врагам и останавливает пули. Двигается твином, физика синхронизирована.

@export var open_offset := Vector2(0, -64)
@export var move_time := 0.3
@export var inverted := false # true — открыта, пока переключатель ВЫКЛЮЧЕН

var _closed_pos: Vector2
var _tween: Tween


func _ready() -> void:
	_closed_pos = position
	sync_to_physics = true


func set_active(on: bool) -> void:
	var open := on != inverted
	var target := _closed_pos + (open_offset if open else Vector2.ZERO)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "position", target, move_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
