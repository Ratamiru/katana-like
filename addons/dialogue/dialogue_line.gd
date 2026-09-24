class_name DialogueLine
extends RefCounted

## Одна реплика, которую надо показать. Текст уже переведён (tr) и с подставленными {выражениями}.
## Если есть choices — после реплики игрок выбирает вариант: runner.choose(индекс).
## Реплика может быть и без текста — только выбор (варианты сразу после if/set и т.п.).

var speaker := ""
var text := ""
var tags := {}        # «#mood=angry #shake» → {mood = "angry", shake = true}
var choices: Array[Dictionary] = [] # {text, tags} — только доступные варианты
var source_line := 0  # строка в .dlg — для отладки


func has_choices() -> bool:
	return not choices.is_empty()


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func get_tag(tag: String, default: Variant = null) -> Variant:
	return tags.get(tag, default)
