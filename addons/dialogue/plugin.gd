@tool
extends EditorPlugin

## Включение плагина добавляет autoload `Dialogue`, выключение — убирает.
## Сами .dlg-файлы грузятся и без плагина (DialogueFormatLoader регистрируется через class_name).

const AUTOLOAD := "Dialogue"


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD, get_script().resource_path.get_base_dir().path_join("dialogue_manager.gd"))


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD)
