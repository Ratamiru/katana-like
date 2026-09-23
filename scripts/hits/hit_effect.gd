class_name HitEffect
extends HitReaction

## Реакция «заспавнить эффект в точке попадания»: кровь, искры, щепки, пыль…
## effect — любая сцена (обычно CPUParticles2D/GPUParticles2D с one_shot).
## Спавнится через Juice.spawn_effect в корень уровня, а не в цель, —
## поэтому брызги остаются, даже если цель сразу умерла и удалилась.
## Эффект повёрнут по hit.direction: локальная ось +X эффекта = направление удара.

@export var effect: PackedScene
@export var offset := Vector2.ZERO # смещение от точки попадания (глобально)


func _react(hit: HitInfo) -> void:
	Juice.spawn_effect(effect, hit.position + offset, hit.direction)
