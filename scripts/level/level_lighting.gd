class_name LevelLighting
extends CanvasModulate

## Освещение уровня — одна нода на уровень (вместо голой CanvasModulate).
##
##   fully_lit = false (по умолчанию) — стелс-уровень: мир затемнён цветом dark_color,
##       светло только у ламп LightSource; враги в темноте видят конусом (Vision).
##   fully_lit = true — уровень освещён целиком (боевые/PvP-уровни):
##       визуальной темноты нет, для врагов игрок всегда «на свету» (LightSource.is_lit → true),
##       косметический ViewLight игрока и тени скрыт (он не нужен и пересвечивает картинку).
##
## Флаг выставляется в LightSource.level_fully_lit в _enter_tree — раньше любых _ready,
## поэтому и враги, и тела игрока видят правильное значение с первого кадра.
## Нет LevelLighting на уровне — действуют правила темноты (но визуально уровень светлый),
## поэтому ставьте эту ноду в каждый уровень.

@export var fully_lit := false:
	set(v):
		fully_lit = v
		if is_inside_tree():
			_apply()
@export var dark_color := Color(0.16, 0.16, 0.22)


func _enter_tree() -> void:
	LightSource.level_fully_lit = fully_lit


func _ready() -> void:
	_apply()


func _exit_tree() -> void:
	LightSource.level_fully_lit = false


func _apply() -> void:
	LightSource.level_fully_lit = fully_lit
	color = Color.WHITE if fully_lit else dark_color
