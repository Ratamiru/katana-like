extends PlayerPawn

## Основное тело игрока: катана в сторону мыши. Управление — см. PlayerPawn,
## тень — дочерний компонент ShadowAbility.


func _ready() -> void:
	super()
	add_to_group("player")
	PlayerPawn.possess(self) # при старте/перезагрузке уровня управляем основным телом
	melee_attack.hit_landed.connect(_on_hit_landed)
	melee_attack.deflected.connect(Juice.hit)
	clinched.connect(func(_other: Fighter) -> void: Juice.clinch())
	damaged.connect(func(_amount: int) -> void: Juice.hurt())


func _on_hit_landed(hit: HitInfo) -> void:
	# Замедление/тряска — только по врагам (группа "enemy"). У пропов своя реакция (HitReaction).
	if not hit.target.is_in_group("enemy"):
		return
	if hit.blocked:
		# Удар в броню — отдача и лёгкая тряска вместо hit-stop.
		apply_knockback(hit.position, knockback * 0.6)
		Juice.shake(0.2)
	elif hit.killed:
		Juice.kill()
	else:
		Juice.hit()


func _update_intent(delta: float) -> void:
	super(delta)
	mouse_pos()


func mouse_pos() -> void:
	var is_left := get_local_mouse_position().x < 0.0
	# sprite.flip_h = is_left  # или scale.x = -1.0 if is_left else 1.0, смотря как у тебя реализован флип


func _primary_action() -> void:
	melee_attack.attack()


func _die() -> void:
	# Пока просто перезапуск уровня.
	get_tree().reload_current_scene.call_deferred()
