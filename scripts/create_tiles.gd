@tool
extends EditorScript


# Called when the script is executed (using File -> Run in Script Editor).
func _run() -> void:
	var img := Image.create(32 * 4, 32, false, Image.FORMAT_RGBA8)
	var colors := [Color.GREEN, Color.GRAY, Color.RED, Color.BLUE]
	for i in colors.size():
		img.fill_rect(Rect2i(i * 32, 0, 32, 32), colors[i])
	img.save_png("res://art/placeholder_tiles.png")
