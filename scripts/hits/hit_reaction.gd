class_name HitReaction
extends Node

## Базовая «реакция на удар». Вешается дочерней нодой на всё, что можно ударить:
## врага, игрока, проп (ящик, бутылку, лампу…). Когда по объекту попадают,
## HitReaction.dispatch() вызывает react(hit) у всех его дочерних реакций.
##
## Так поведение при ударе собирается из кубиков в редакторе, без кода:
##   враг   = HitEffect(кровь) + HitEffect(кровь посильнее, только LETHAL)
##   ящик   = HitEffect(щепки) + <своя реакция: толкнуть / разрушить>
##   лампа  = HitEffect(искры) + <своя реакция: погаснуть>
## Новая реакция — это новый скрипт `extends HitReaction` с переопределённым _react().
##
## Фильтры (настраиваются в инспекторе):
##   trigger — на любой удар / только не смертельный / только смертельный;
##   kinds   — только на определённые виды ударов (&"melee", &"bullet"); пусто — на все.

enum Trigger { ANY, NON_LETHAL, LETHAL }

@export var enabled := true
@export var trigger := Trigger.ANY
@export var kinds: Array[StringName] = []


## Разослать попадание всем реакциям цели. Вызывают MeleeAttack и BulletWorld.
static func dispatch(target: Node, hit: HitInfo) -> void:
	if target == null:
		return
	for child in target.get_children():
		if child is HitReaction:
			child.react(hit)


## Есть ли у объекта хоть одна реакция на удар.
static func has_reactions(target: Node) -> bool:
	if target == null:
		return false
	for child in target.get_children():
		if child is HitReaction:
			return true
	return false


func react(hit: HitInfo) -> void:
	if not enabled:
		return
	if trigger == Trigger.NON_LETHAL and hit.killed:
		return
	if trigger == Trigger.LETHAL and not hit.killed:
		return
	if not kinds.is_empty() and hit.kind not in kinds:
		return
	_react(hit)


## Переопределяется наследниками.
func _react(_hit: HitInfo) -> void:
	pass
