class_name ObjectiveSignal
extends Objective

## Универсальная цель: нода source выпустила сигнал signal_name count раз.
## Покрывает почти всё без нового кода:
##   дёрнуть рычаг        — source: Lever,  signal: switched, first_arg: TRUE_ONLY;
##   сломать объект/турель — source: Turret, signal: died;
##   зайти в зону          — source: Area2D-триггер со своим сигналом (entered и т.п.);
##   подобрать N предметов — source: инвентарь/счётчик, signal: picked, count: N.
## События до активации (порядок SEQUENTIAL) не считаются — это «сделай после».

enum ArgFilter { ANY, TRUE_ONLY, FALSE_ONLY } # фильтр по первому аргументу сигнала (bool)

@export var source: NodePath
@export var signal_name: StringName = &""
@export var count := 1
@export var first_arg := ArgFilter.ANY


func _on_activated() -> void:
	required = maxi(count, 1)
	var src := get_node_or_null(source)
	if src == null or not src.has_signal(signal_name):
		push_warning("%s: нет ноды %s или сигнала %s" % [name, source, signal_name])
		return
	# Сколько аргументов у сигнала — чтобы подключить обработчик с правильной арностью.
	var argc := 0
	for s in src.get_signal_list():
		if s.name == signal_name:
			argc = s.args.size()
			break
	if argc == 0:
		src.connect(signal_name, _on_signal0)
	else:
		src.connect(signal_name, _on_signal1.unbind(argc - 1)) # берём только первый аргумент


func _on_signal0() -> void:
	set_progress(progress + 1)


func _on_signal1(arg: Variant) -> void:
	if first_arg == ArgFilter.TRUE_ONLY and not arg:
		return
	if first_arg == ArgFilter.FALSE_ONLY and arg:
		return
	set_progress(progress + 1)
