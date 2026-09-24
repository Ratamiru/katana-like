extends CanvasLayer

## ScreenFX — полноэкранные эффекты-телеграфы. Autoload, доступен как `ScreenFX`.
##
## Два вида эффектов:
##   • состояние  — enter(id) / exit(id): держится, пока не сняли
##                  (управление тенью, в будущем — оглушение игрока, мало HP…);
##   • импульс    — pulse(name): вспыхивает и гаснет сам (клинч, урон, убийство).
##
## Эффекты задаются пресетами ScreenFXPreset (тонировка, виньетка, обесцвечивание,
## хроматическая аберрация + огибающая). Все активные эффекты каждый кадр
## смешиваются в один набор параметров одного шейдера на одном ColorRect:
##   амплитуды — складываются (и обрезаются до 1), цвета — среднее, взвешенное по силе.
## Если ничего не активно — ColorRect скрыт, шейдер не считается вовсе.
##
## Время реальное (Time.get_ticks_usec): оверлей не тормозит в slow-mo.
## Слой CanvasLayer — LAYER. HUD класть на слой выше, иначе эффекты лягут и на него.
## intensity — общий множитель (0 — выключить всё: доступность, настройки).
##
## Кто вызывает: события — через Juice (Juice.clinch() сам зовёт ScreenFX.pulse),
## длительные состояния — напрямую (ShadowAbility → enter/exit(&"shadow")).

const LAYER := 100
const SHADER := preload("res://shaders/screen_fx.gdshader")

## Общая сила всех эффектов (0..1). 0 — оверлей выключен.
var intensity := 1.0

var presets: Dictionary = {} # StringName -> ScreenFXPreset

var _rect: ColorRect
var _mat: ShaderMaterial
var _states := {} # id -> {preset, weight, target}
var _pulses: Array[Dictionary] = [] # {preset, t}
var _last_usec := 0


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)
	_last_usec = Time.get_ticks_usec()
	_register_defaults()


# ── Пресеты по умолчанию. Тюнить здесь (или заменить через register). ──

func _register_defaults() -> void:
	# Управление тенью: фиолетовая густая виньетка, мир серее.
	register(&"shadow", ScreenFXPreset.make({
		tint_color = Color(0.35, 0.15, 0.6), tint = 0.12,
		vignette_color = Color(0.12, 0.02, 0.22), vignette = 0.85,
		desaturate = 0.5, fade_in = 0.15, fade_out = 0.25,
	}))
	# Клинч: короткая белая вспышка + аберрация.
	register(&"clinch", ScreenFXPreset.make({
		tint_color = Color.WHITE, tint = 0.3, aberration = 0.7,
		fade_in = 0.0, hold = 0.03, fade_out = 0.22,
	}))
	# Добивание: лёгкая аберрация и обесцвечивание.
	register(&"kill", ScreenFXPreset.make({
		aberration = 0.45, desaturate = 0.35,
		fade_in = 0.0, hold = 0.05, fade_out = 0.3,
	}))
	# Игрока ранили: красная виньетка.
	register(&"hurt", ScreenFXPreset.make({
		tint_color = Color(0.8, 0.0, 0.0), tint = 0.08,
		vignette_color = Color(0.55, 0.0, 0.0), vignette = 0.9,
		fade_in = 0.0, hold = 0.05, fade_out = 0.4,
	}))


# ── API ──

func register(preset_name: StringName, preset: ScreenFXPreset) -> void:
	presets[preset_name] = preset


## Включить состояние id (пресет — по имени preset_name, по умолчанию = id).
func enter(id: StringName, preset_name: StringName = &"") -> void:
	var p: ScreenFXPreset = presets.get(preset_name if preset_name else id)
	if p == null:
		push_warning("ScreenFX: нет пресета %s" % (preset_name if preset_name else id))
		return
	var st: Dictionary = _states.get(id, {weight = 0.0})
	st.preset = p
	st.target = 1.0
	_states[id] = st


## Снять состояние id (плавно, по fade_out пресета).
func exit(id: StringName) -> void:
	if _states.has(id):
		_states[id].target = 0.0


func is_active(id: StringName) -> bool:
	return _states.has(id) and _states[id].target > 0.0


## Одноразовый эффект по имени пресета.
func pulse(preset_name: StringName) -> void:
	var p: ScreenFXPreset = presets.get(preset_name)
	if p == null:
		push_warning("ScreenFX: нет пресета %s" % preset_name)
		return
	pulse_preset(p)


func pulse_preset(p: ScreenFXPreset) -> void:
	_pulses.append({preset = p, t = 0.0})


## Сбросить всё мгновенно.
func clear() -> void:
	_states.clear()
	_pulses.clear()
	_rect.visible = false


# ── Кадр ──

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := float(now - _last_usec) / 1_000_000.0
	_last_usec = now

	var sources: Array = [] # [preset, weight]

	for id: StringName in _states.keys():
		var st: Dictionary = _states[id]
		var p: ScreenFXPreset = st.preset
		if st.target > st.weight:
			st.weight = 1.0 if p.fade_in <= 0.0 else minf(st.weight + dt / p.fade_in, 1.0)
		elif st.target < st.weight:
			st.weight = 0.0 if p.fade_out <= 0.0 else maxf(st.weight - dt / p.fade_out, 0.0)
		if st.weight <= 0.0 and st.target <= 0.0:
			_states.erase(id)
		else:
			sources.append([p, st.weight])

	for i in range(_pulses.size() - 1, -1, -1):
		var pl: Dictionary = _pulses[i]
		pl.t += dt
		var p: ScreenFXPreset = pl.preset
		var w := _envelope(p, pl.t)
		if w < 0.0:
			_pulses.remove_at(i)
		else:
			sources.append([p, w])

	_apply(sources)


## Огибающая импульса: 0→1 за fade_in, держит hold, 1→0 за fade_out. -1 — закончился.
func _envelope(p: ScreenFXPreset, t: float) -> float:
	if t < p.fade_in:
		return t / p.fade_in
	t -= p.fade_in
	if t < p.hold:
		return 1.0
	t -= p.hold
	if t < p.fade_out:
		return 1.0 - t / p.fade_out
	return -1.0


func _apply(sources: Array) -> void:
	var tint := 0.0
	var vignette := 0.0
	var desat := 0.0
	var aberr := 0.0
	var tint_col := Color(0, 0, 0)
	var vig_col := Color(0, 0, 0)
	for s in sources:
		var p: ScreenFXPreset = s[0]
		var w: float = s[1]
		tint += p.tint * w
		vignette += p.vignette * w
		desat += p.desaturate * w
		aberr += p.aberration * w
		tint_col += p.tint_color * (p.tint * w)
		vig_col += p.vignette_color * (p.vignette * w)
	if tint > 0.0:
		tint_col /= tint
	if vignette > 0.0:
		vig_col /= vignette

	var k := clampf(intensity, 0.0, 1.0)
	tint = minf(tint, 1.0) * k
	vignette = minf(vignette, 1.0) * k
	desat = minf(desat, 1.0) * k
	aberr = minf(aberr, 1.0) * k

	_rect.visible = tint + vignette + desat + aberr > 0.001
	if not _rect.visible:
		return
	_mat.set_shader_parameter("tint_color", tint_col)
	_mat.set_shader_parameter("tint_amount", tint)
	_mat.set_shader_parameter("vignette_color", vig_col)
	_mat.set_shader_parameter("vignette_amount", vignette)
	_mat.set_shader_parameter("desaturate", desat)
	_mat.set_shader_parameter("aberration", aberr)
