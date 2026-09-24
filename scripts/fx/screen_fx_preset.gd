class_name ScreenFXPreset
extends Resource

## Описание одного полноэкранного эффекта для ScreenFX.
## Можно создать .tres в редакторе (New Resource → ScreenFXPreset) и
## зарегистрировать: ScreenFX.register(&"name", preload("...tres")).
##
## Амплитуды (0..1) — сила каждого слоя шейдера. Цвета смешиваются между
## активными эффектами пропорционально их силе.
## Огибающая: fade_in → hold → fade_out (реальные секунды).
## Для состояний (enter/exit) hold не используется: держится, пока не сняли.

@export var tint_color := Color.WHITE
@export_range(0.0, 1.0) var tint := 0.0
@export var vignette_color := Color.BLACK
@export_range(0.0, 1.0) var vignette := 0.0
@export_range(0.0, 1.0) var desaturate := 0.0
@export_range(0.0, 1.0) var aberration := 0.0
@export var fade_in := 0.0
@export var hold := 0.0
@export var fade_out := 0.2


static func make(params: Dictionary) -> ScreenFXPreset:
	var p := ScreenFXPreset.new()
	for key in params:
		p.set(key, params[key])
	return p
