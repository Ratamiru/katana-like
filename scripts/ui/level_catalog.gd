class_name LevelCatalog
extends RefCounted

## Каталог уровней — единственное место, где перечислены все уровни игры по порядку.
## Порядок важен: следующий уровень открывается после прохождения предыдущего,
## первый открыт всегда. Новый уровень = новая строка в LEVELS.
## Меню «Загрузить» строит список уровней отсюда, Progress сверяется с ним.

const LEVELS := [ # {path, title}
	{path = "res://world.tscn", title = "Уровень 1 — Пролог"},
	{path = "res://levels/mansion.tscn", title = "Mansion"},
]


## Путь первого уровня (с него начинается новая игра).
static func first_path() -> String:
	if LEVELS.is_empty():
		return ""
	return LEVELS[0].path


## Номер уровня в каталоге, -1 — нет такого.
static func index_of(path: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i].path == path:
			return i
	return -1


static func has(path: String) -> bool:
	return index_of(path) >= 0


## Отображаемое название; для неизвестного пути — сам путь.
static func title_of(path: String) -> String:
	var i := index_of(path)
	if i < 0:
		return path
	return LEVELS[i].title
