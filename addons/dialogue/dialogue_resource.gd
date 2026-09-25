@tool
class_name DialogueResource
extends Resource

## Скомпилированный диалог. Обычно получается загрузкой .dlg-файла
## (load / preload / перетащить файл в @export var x: DialogueResource),
## либо из строки — DialogueResource.from_string(text).
##
## source — исходный текст диалога. Хранится в ресурсе, поэтому ресурс можно
## сохранить обратно (DialogueFormatSaver: Duplicate / Save As в редакторе) и
## поправить прямо в инспекторе — при изменении source диалог перекомпилируется.

## Исходный текст .dlg. Изменение → перекомпиляция.
@export_multiline var source := "":
	set(value):
		source = value
		_rebuild()

var code: Array[Dictionary] = []
var nodes := {} # имя узла → индекс инструкции
var errors := PackedStringArray()

var _source_path := "" # для сообщений об ошибках, пока resource_path ещё не выставлен


static func from_string(text: String, path := "") -> DialogueResource:
	var res := DialogueResource.new()
	res.compile(text, path)
	return res


## Скомпилировать текст (path — только для сообщений об ошибках).
func compile(text: String, path := "") -> void:
	_source_path = path
	source = text # сеттер перекомпилирует


func has_node(node_name: String) -> bool:
	return nodes.has(node_name)


func _rebuild() -> void:
	var path := _source_path if _source_path != "" else resource_path
	var result := DialogueParser.parse(source, path)
	code = result.code
	nodes = result.nodes
	errors = result.errors
	for e in errors:
		push_error("Dialogue: " + e)
