@tool
class_name DialogueFormatSaver
extends ResourceFormatSaver

## Учит Godot СОХРАНЯТЬ DialogueResource обратно в .dlg: пишет исходный текст (source).
## Нужен редактору: Duplicate в FileSystem (он делает load → save под новым именем),
## Save As, сохранение после правки source в инспекторе. Без него — «File unrecognized».
## Как и загрузчик, регистрируется движком сам благодаря class_name.


func _recognize(resource: Resource) -> bool:
	return resource is DialogueResource


func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	if resource is DialogueResource:
		return PackedStringArray(["dlg"])
	return PackedStringArray()


func _save(resource: Resource, path: String, _flags: int) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string((resource as DialogueResource).source)
	return OK
