class_name Shadow
extends PlayerPawn

## Тень — второе тело игрока. Та же физика движения, что у Fighter
## (бег, прыжки, стены), но свои компоненты: вместо катаны — GrabAttack.
## Живёт в реальном времени (unscaled_time), пока мир замедлен.
## Жизненным циклом (появление, передача управления, исчезновение)
## управляет ShadowAbility основного тела.

signal grabbed(target: Node)

@onready var grab_attack: GrabAttack = $GrabAttack


func _ready() -> void:
	super()
	grab_attack.grabbed.connect(_on_grabbed)


func _primary_action() -> void:
	grab_attack.attack()


func _on_grabbed(target: Node) -> void:
	# Прилипаем к цели, чтобы было видно, кто её держит.
	if target is Node2D:
		global_position = (target as Node2D).global_position - Vector2(facing * 10.0, 0)
		velocity = Vector2.ZERO
	grabbed.emit(target)


## Плавно исчезнуть и удалиться.
func vanish(time := 0.25) -> void:
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, time)
	tw.tween_callback(queue_free)


## Тень неуязвима: на её слое никого нет, но на всякий случай.
func take_damage(_amount: int, _from := global_position) -> bool:
	return false
