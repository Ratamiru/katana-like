class_name HitInfo
extends RefCounted

## Описание одного попадания — передаётся всем реакциям цели (HitReaction).
## Создаётся тем, кто бьёт: MeleeAttack (kind = &"melee") или BulletWorld (kind = &"bullet").

var attacker: Node # кто ударил; у пуль — null
var target: Node # в кого попали
var position: Vector2 # точка попадания (глобальная)
var direction: Vector2 # куда летел удар/пуля (нормализован) — туда же летят брызги
var damage: int
var kind: StringName # &"melee", &"bullet", … — реакции могут фильтровать по нему
var killed := false # цель умерла от этого удара (заполняется после take_damage)
var blocked := false # урон не прошёл (броня): take_damage вернул false


static func make(p_attacker: Node, p_target: Node, p_position: Vector2, p_direction: Vector2, p_damage: int, p_kind: StringName) -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = p_attacker
	hit.target = p_target
	hit.position = p_position
	hit.direction = p_direction.normalized()
	hit.damage = p_damage
	hit.kind = p_kind
	return hit
