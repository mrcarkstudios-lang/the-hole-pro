extends SceneTree
## Renders icon.svg to PNG files (boot splash needs PNG).
func _initialize() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var img := Image.new()
	img.load_svg_from_string(svg, 2.0)
	img.save_png("res://splash.png")
	print("splash ", img.get_size())
	quit()
