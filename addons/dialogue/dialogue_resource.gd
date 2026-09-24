@tool
class_name DialogueResource
extends Resource

## Скомпилированный диалог. Обычно получается загрузкой .dlg-файла
## (load / preload / перетащить файл в @export var x: DialogueResource),
## либо из строки — DialogueResource.from_string(text).

var code: Array[Dictionary] = []
var nodes := {} # имя узла → индекс инструкции
var errors := PackedStringArray()


static func from_string(source: String, path := "") -> DialogueResource:
	var res := DialogueResource.new()
	res.compile(source, path)
	return res


func compile(source: String, path := "") -> void:
	var result := DialogueParser.parse(source, path)
	code = result.code
	nodes = result.nodes
	errors = result.errors
	for e in errors:
		push_error("Dialogue: " + e)


func has_node(node_name: String) -> bool:
	return nodes.has(node_name)
