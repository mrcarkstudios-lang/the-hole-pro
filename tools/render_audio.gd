extends SceneTree
## Bakes music + sfx into res://assets/audio/*.res (run on the PC, not the phone):
##   godot --headless --path . --script res://tools/render_audio.gd
func _initialize() -> void:
	var sfx := Sfx.new()
	root.add_child(sfx)
	sfx.bake()
	var r := Music.render(Music.RATE)
	for l in Music.LAYERS:
		var w := Music._make_stream(r["pcm"][l], Music.RATE, int(r["n"]))
		ResourceSaver.save(w, Music.BAKED % l)
	print("baked audio, loop samples ", r["n"])
	quit()
