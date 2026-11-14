class_name Intro
extends Control
## Opening animation (~4 s, tap to skip) built from the art-pack images: the city backdrop drifts in,
## the hole opens and spins, toy objects spiral into it (one musical note each), then the logo bursts out
## with a shock ring and sparkles, and the tagline slides in.

signal finished
signal hit(sound_name: String)

const UI := "res://assets/ui/%s"
const ITEM_START := 0.5
const ITEM_GAP := 0.2
const ITEM_FLIGHT := 0.62
const OBJECTS := ["car", "tree", "crate", "gold", "person", "bus", "house", "skyscraper"]

var t: float = 0.0
var done: bool = false
var items: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var hole_scale: float = 0.0
var pulse: float = 0.0
var flash: float = 0.0
var fade_in: float = 0.0
var logo_p: float = 0.0
var tag_p: float = 0.0
var title_started: bool = false
var tag_started: bool = false
var hole_c: Vector2 = Vector2.ZERO
var vs: Vector2 = Vector2(1280, 720)
var logo_target: Vector2 = Vector2.ZERO
var tex_bg: Texture2D
var tex_hole: Texture2D
var tex_logo: Texture2D
var tex_tag: Texture2D
var tex_ring: Texture2D
var tex_spark: Texture2D
var tex_dust: Texture2D
var tex_obj: Dictionary = {}
var rng := RandomNumberGenerator.new()
var fx_layer: Control
var shake: float = 0.0
var warm: bool = false   # true when following the brand card (same hole, same backdrop)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	vs = get_viewport_rect().size
	hole_c = Vector2(vs.x * 0.5, vs.y * 0.64)
	logo_target = Vector2(vs.x * 0.5, vs.y * 0.27)
	tex_bg = load(UI % "intro_bg.jpg")
	tex_hole = load(UI % "intro_hole.png")
	tex_logo = load(UI % "intro_logo.png")
	tex_tag = load(UI % "intro_tagline.png")
	tex_ring = load(UI % "fx_ring.png")
	tex_spark = load(UI % "fx_sparkle.png")
	tex_dust = load(UI % "fx_dust.png")
	for o in OBJECTS:
		tex_obj[o] = load(UI % ("obj_" + o + ".png"))
	var starts: Array[Vector2] = [Vector2(-0.55, -0.1), Vector2(0.55, -0.28), Vector2(-0.3, -0.62), Vector2(0.38, -0.66),
		Vector2(-0.58, 0.18), Vector2(0.58, 0.05), Vector2(-0.12, -0.7), Vector2(0.12, -0.7)]
	for i in OBJECTS.size():
		items.append({"kind": OBJECTS[i], "from": Vector2(starts[i].x * vs.x, starts[i].y * vs.y),
			"delay": ITEM_START + float(i) * ITEM_GAP, "fired": false, "spin": rng.randf_range(-5.0, 5.0)})
	# additive layer for light rays and flares
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx_layer.material = add_mat
	fx_layer.draw.connect(_draw_fx)
	add_child(fx_layer)
	if warm:
		hole_scale = 1.0
		fade_in = 1.0
		pulse = 1.0
	else:
		create_tween().tween_property(self, "hole_scale", 1.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(self, "fade_in", 1.0, 0.35)


func _burst(pos: Vector2, n: int, speed: float, life: float = 0.7) -> void:
	for k in n:
		var a := rng.randf() * TAU
		sparks.append({"p": pos, "v": Vector2.from_angle(a) * rng.randf_range(speed * 0.4, speed),
			"life": life * rng.randf_range(0.7, 1.2), "age": 0.0, "s": rng.randf_range(0.12, 0.3), "r": rng.randf() * TAU})


func _start_title() -> void:
	title_started = true
	flash = 1.0
	pulse = 1.0
	hit.emit("go")
	shake = 1.0
	_burst(hole_c, 46, 600.0, 1.0)
	_burst(logo_target, 24, 360.0, 0.9)
	var tw := create_tween()
	tw.tween_property(self, "logo_p", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	shake = maxf(0.0, shake - delta * 2.6)
	position = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake * 9.0
	fx_layer.queue_redraw()
	pulse = maxf(0.0, pulse - delta * 3.0)
	flash = maxf(0.0, flash - delta * 1.8)
	var i := 0
	while i < sparks.size():
		var s := sparks[i]
		s["age"] = float(s["age"]) + delta
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
		s["v"] = (s["v"] as Vector2) * (1.0 - 2.2 * delta)
		if float(s["age"]) >= float(s["life"]):
			sparks[i] = sparks.back()
			sparks.pop_back()
			continue
		i += 1
	for k in items.size():
		var it: Dictionary = items[k]
		var p: float = (t - float(it["delay"])) / ITEM_FLIGHT
		if p >= 1.0 and not it["fired"]:
			it["fired"] = true
			pulse = 1.0
			shake = maxf(shake, 0.28 + 0.03 * float(k))
			hit.emit("pop:%d" % (k * 2))
			_burst(hole_c, 10, 300.0, 0.55)
	var title_t := ITEM_START + float(items.size()) * ITEM_GAP + ITEM_FLIGHT * 0.5
	if not title_started and t >= title_t:
		_start_title()
	if title_started and not tag_started and t >= title_t + 0.55:
		tag_started = true
		create_tween().tween_property(self, "tag_p", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if t >= title_t + 3.6:
		_finish()
	queue_redraw()


func _input(e: InputEvent) -> void:
	if done:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed):
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if done:
		return
	done = true
	position = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func():
		finished.emit()
		queue_free())


func _tex(tex: Texture2D, center: Vector2, size: Vector2, rot: float = 0.0, col: Color = Color.WHITE) -> void:
	draw_set_transform(center, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _item_pos(it: Dictionary, p: float) -> Vector2:
	var e := p * p * (3.0 - 2.0 * p)
	var from: Vector2 = it["from"]
	var swirl := Vector2.from_angle(p * 5.0 + float(it["spin"])) * 60.0 * (1.0 - p)
	return hole_c + from * (1.0 - e) + swirl + Vector2(0, -80.0 * sin(p * PI))


## Additive layer: rotating light rays behind the hole, big flare when the logo bursts out.
func _draw_fx() -> void:
	var a := 0.07 * hole_scale + 0.06 * pulse + flash * 0.16
	var n := 14
	for k in n:
		var a0 := float(k) / float(n) * TAU + t * 0.35
		var a1 := a0 + TAU / float(n) * 0.45
		fx_layer.draw_colored_polygon(PackedVector2Array([hole_c, hole_c + Vector2.from_angle(a0) * 1100.0, hole_c + Vector2.from_angle(a1) * 1100.0]), Color(1.0, 0.8, 0.3, a))
	if flash > 0.0:
		var fs := 1000.0 * flash + 200.0
		fx_layer.draw_set_transform(hole_c, t * 0.5, Vector2.ONE)
		fx_layer.draw_texture_rect(tex_spark, Rect2(-Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false, Color(1, 0.9, 0.6, flash))
		fx_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if title_started:
		var g := clampf(logo_p, 0.0, 1.0) * (0.35 + 0.1 * sin(t * 4.0))
		fx_layer.draw_set_transform(logo_target, 0.0, Vector2.ONE)
		fx_layer.draw_texture_rect(tex_spark, Rect2(Vector2(-460, -150), Vector2(920, 300)), false, Color(1, 0.85, 0.4, g * 0.5))
		fx_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	# backdrop: slow push-in on the skyline, darkened so the hole and logo pop
	var z := 1.0 + 0.07 * clampf(t / 4.0, 0.0, 1.0)
	var bs := vs * z
	draw_texture_rect(tex_bg, Rect2((vs - bs) * 0.5, bs), false, Color(1, 1, 1, fade_in))
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.04, 0.16, 0.5 * fade_in))
	# soft golden glow behind the hole
	for k in 6:
		var rr := (300.0 - float(k) * 40.0) * hole_scale * (1.0 + 0.12 * pulse)
		draw_circle(hole_c, rr, Color(1.0, 0.8, 0.2, 0.04 + flash * 0.05))
	# the hole (spins slowly, pops on every swallow)
	var hs := 330.0 * hole_scale * (1.0 + 0.1 * pulse)
	if hs > 2.0:
		_tex(tex_hole, hole_c, Vector2(hs, hs), t * 0.9)
	# objects spiral into the hole
	for it in items:
		var p: float = clampf((t - float(it["delay"])) / ITEM_FLIGHT, 0.0, 1.0)
		if t < float(it["delay"]) or p >= 1.0:
			continue
		for g in range(4, 0, -1):
			var pg := clampf(p - float(g) * 0.045, 0.0, 1.0)
			if pg <= 0.0:
				continue
			var gs := 150.0 * (1.0 - smoothstep(0.65, 1.0, pg) * 0.95)
			_tex(tex_obj[it["kind"]], _item_pos(it, pg), Vector2(gs, gs), pg * float(it["spin"]) * 0.6, Color(1, 1, 1, 0.13 * float(5 - g)))
		var sc := 1.0 - smoothstep(0.65, 1.0, p) * 0.95
		var sz := 170.0 * sc
		_tex(tex_obj[it["kind"]], _item_pos(it, p), Vector2(sz, sz), p * float(it["spin"]) * 0.6, Color(1, 1, 1, 1.0 - smoothstep(0.9, 1.0, p)))
	# shock ring + logo burst
	if flash > 0.0:
		var rs := 260.0 + 1100.0 * (1.0 - flash)
		_tex(tex_ring, hole_c, Vector2(rs, rs), 0.0, Color(1, 1, 1, flash))
	if title_started:
		var lw := 760.0
		var lh := lw * float(tex_logo.get_height()) / float(tex_logo.get_width())
		var pos := hole_c.lerp(logo_target, clampf(logo_p, 0.0, 1.2))
		var sc := maxf(logo_p, 0.0)
		var wob := 1.0 + 0.025 * sin((t - 3.0) * 3.0) * clampf(logo_p, 0.0, 1.0)
		_tex(tex_logo, pos, Vector2(lw, lh) * sc * wob, sin(t * 2.0) * 0.012 * logo_p, Color(1, 1, 1, clampf(logo_p * 2.0, 0.0, 1.0)))
	if tag_started:
		var tw_ := 540.0
		var th := tw_ * float(tex_tag.get_height()) / float(tex_tag.get_width())
		var tpos := Vector2(vs.x * 0.5, logo_target.y + 175.0 + 24.0 * (1.0 - tag_p))
		_tex(tex_tag, tpos, Vector2(tw_, th) * (0.8 + 0.2 * tag_p), 0.0, Color(1, 1, 1, clampf(tag_p, 0.0, 1.0)))
	# particles
	for s in sparks:
		var a := 1.0 - float(s["age"]) / float(s["life"])
		var ss := 150.0 * float(s["s"]) * (0.4 + 0.6 * a)
		_tex(tex_spark, s["p"], Vector2(ss, ss), float(s["r"]) + float(s["age"]) * 4.0, Color(1, 1, 1, a))
