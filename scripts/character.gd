extends Fighter

## Игрок: намерения движения берутся из инпута, атака — в сторону мыши.


func _ready() -> void:
	super()
	add_to_group("player")
	melee_attack.hit_landed.connect(_on_hit_landed)
	melee_attack.deflected.connect(Juice.hit)
	clinched.connect(func(_other: Fighter) -> void: Juice.clinch())


func _on_hit_landed(target: Node) -> void:
	# Замедление/тряска — только по бойцам. У пропов своя реакция (HitReaction).
	if target is not Fighter:
		return
	if target.is_dead:
		Juice.kill()
	else:
		Juice.hit()


func _update_intent(_delta: float) -> void:
	move_dir = Input.get_axis("backward", "forward")
	jump_requested = Input.is_action_just_pressed("jump")
	drop_requested = Input.is_action_pressed("down")
	mouse_pos()


func mouse_pos() -> void:
	var is_left := get_local_mouse_position().x < 0.0
	# sprite.flip_h = is_left  # или scale.x = -1.0 if is_left else 1.0, смотря как у тебя реализован флип


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not is_dead:
		melee_attack.attack()


func _die() -> void:
	# Пока просто перезапуск уровня.
	get_tree().reload_current_scene.call_deferred()
