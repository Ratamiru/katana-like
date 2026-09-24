@tool
class_name DialogueFormatLoader
extends ResourceFormatLoader

## Учит Godot грузить .dlg как DialogueResource: load("res://x.dlg"), preload, ext_resource в сценах.
## Загрузчик с class_name регистрируется движком сам (и в редакторе, и в игре) — плагин для этого не нужен.
## Файл компилируется при загрузке, ошибки синтаксиса сразу видны в Output / Debugger.

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["dlg"])


func _handles_type(type: StringName) -> bool:
	return type == &"Resource"


func _get_resource_type(path: String) -> String:
	return "Resource" if path.get_extension() == "dlg" else ""


func _get_resource_script_class(path: String) -> String:
	return "DialogueResource" if path.get_extension() == "dlg" else ""


func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var res := DialogueResource.new()
	res.compile(file.get_as_text(), path)
	return res
