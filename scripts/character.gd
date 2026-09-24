extends PlayerPawn

## Основное тело игрока: катана в сторону мыши с выпадом. Управление — см. PlayerPawn,
## тень — дочерний компонент ShadowAbility.
## Смерть с одного удара (max_health = 1 в сцене) и мгновенный рестарт уровня;
## `restart` (R) — рестарт в любой момент.

## Реальных сек между смертью и перезапуском — успеть увидеть, что убило. 0 — сразу.
@export var restart_delay := 0.15

var _restarting := false


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
	if not melee_attack.can_attack():
		return
	var dir := get_local_mouse_position()
	melee_attack.attack(dir)
	lunge(dir)


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if event.is_action_pressed("restart"):
		restart_level(0.0)


func _die() -> void:
	# Тело не удаляем — оно «лежит», пока идёт короткая пауза до рестарта.
	restart_level(restart_delay)


## Перезапустить уровень через delay реальных секунд (не зависит от замедления).
func restart_level(delay: float) -> void:
	if _restarting:
		return
	_restarting = true
	if delay > 0.0:
		await get_tree().create_timer(delay, true, false, true).timeout
	# Чистый старт: без хвостов замедления и экранных эффектов прошлой попытки.
	Juice.reset()
	ScreenFX.clear()
	get_tree().reload_current_scene.call_deferred()
