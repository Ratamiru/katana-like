class_name DialogueTrigger
extends Area2D

## Зона, запускающая диалог: у NPC (подойти и нажать use), на входе в комнату (сам),
## или по команде — set_active(true), поэтому триггер может быть целью переключателя.
##
## Коллизию (форму и collision_mask под слой игрока) задаёт сцена.
## В диалоге доступно имя `trigger` — этот узел (`do trigger.queue_free()` и т.п.).

signal finished

enum Mode {
	ON_USE,   ## игрок в зоне нажал use_action
	ON_ENTER, ## игрок вошёл в зону
	MANUAL,   ## только start() / set_active(true)
}

@export var dialogue: DialogueResource
@export var start_node := "start"
@export var mode := Mode.ON_USE
@export var once := false ## сработать только один раз
@export var body_group: StringName = &"player" ## кто может запустить (пусто — любое тело)
@export var use_action: StringName = &"use"
@export var prompt: CanvasItem ## подсказка «E», видна, пока игрок рядом

var _bodies := 0
var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_prompt()


func can_start() -> bool:
	return dialogue != null and not (once and _used) and not Dialogue.is_active()


func start() -> void:
	if not can_start():
		return
	_used = true
	_update_prompt()
	if Dialogue.start(dialogue, start_node, {trigger = self}) == null:
		return
	await Dialogue.ended
	_update_prompt()
	finished.emit()


## Совместимость с Switch: цель переключателя.
func set_active(on: bool) -> void:
	if on:
		start()


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.ON_USE and _bodies > 0 and event.is_action_pressed(use_action) and can_start():
		get_viewport().set_input_as_handled()
		start()


func _on_body_entered(body: Node2D) -> void:
	if body_group.is_empty() or body.is_in_group(body_group):
		_bodies += 1
		_update_prompt()
		if mode == Mode.ON_ENTER:
			start()


func _on_body_exited(body: Node2D) -> void:
	if body_group.is_empty() or body.is_in_group(body_group):
		_bodies = maxi(_bodies - 1, 0)
		_update_prompt()


func _update_prompt() -> void:
	if prompt:
		prompt.visible = mode == Mode.ON_USE and _bodies > 0 and can_start()
