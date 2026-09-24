class_name ObjectiveKill
extends Objective

## Убить цели: конкретные ноды из targets и/или всех из группы group
## (группа берётся на момент активации, например &"enemy" — «зачистить уровень»).
##
## Смерть ловится по сигналу `died` цели (есть у Fighter и Turret). Для новых
## убиваемых объектов — тоже эмитить `died`. Цели, уже мёртвые/удалённые к моменту
## активации (важно для порядка SEQUENTIAL), засчитываются сразу.

@export var targets: Array[NodePath] = []
@export var group: StringName = &""


func _on_activated() -> void:
	var alive: Array[Node] = []
	var dead := 0
	for path in targets:
		var n := get_node_or_null(path)
		if n == null or _is_dead(n):
			dead += 1 # уже убит (удалён) до активации
		elif n not in alive:
			alive.append(n)
	if group != &"":
		for n in get_tree().get_nodes_in_group(group):
			if n not in alive and not _is_dead(n):
				alive.append(n)

	required = maxi(alive.size() + dead, 1)
	for n in alive:
		if n.has_signal("died"):
			n.connect(&"died", _on_target_died, CONNECT_ONE_SHOT)
		else:
			push_warning("%s: у %s нет сигнала died — не засчитается" % [name, n.name])
	set_progress(dead if alive.size() + dead > 0 else required) # пустой список — выполнено


func _on_target_died() -> void:
	set_progress(progress + 1)


func _is_dead(n: Node) -> bool:
	return n.is_queued_for_deletion() or n.get("is_dead") == true
