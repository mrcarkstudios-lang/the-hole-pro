class_name BrandIntro
extends Control
## Studio brand card, themed to THIS game: the game's skyline backdrop and golden hole open up, the
## studio logo (Gamics) rises out of the hole with the original brand sting, "PRESENTS" appears,
## then the logo is swallowed by the hole and the game intro takes over seamlessly.
##
## To reuse for another game: change BACKDROP / HOLE / the fx textures and the colours below.

signal finished

const UI := "res://assets/ui/%s"
const BACKDROP := "intro_bg.jpg"
const HOLE := "intro_hole.png"
const LOGO_AT := 0.9      # logo bursts out
const PRESENTS_AT := 1.9
const SWALLOW_AT := 3.1   # logo shrinks into the hole
const END_AT := 3.7

var t := 0.0
var done := false
var vs := Vector2(1280, 720)
var hole_c := Vector2.ZERO
var logo_c := Vector2.ZERO
var pres_c := Vector2.ZERO
var hole_scale := 0.0
var pulse := 0.0
var flash := 0.0
var shake := 0.0
var fade_in := 0.0
var logo_started := false
var pres_started := false
var swallowed := false
var logo_p := 0.0
var pres_p := 0.0
var swallow_p := 0.0
var tex_bg: Texture2D
var tex_hole: Texture2D
var tex_logo: Texture2D
var tex_pres: Texture2D
var tex_ring: Texture2D
var tex_spark: Texture2D
var sparks: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var fx_layer: Control
var sting: AudioStreamPlayer


func _ready() -> void:
	vs = get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	hole_c = Vector2(vs.x * 0.5, vs.y * 0.64)   # same spot as the game intro, so the hand-off is seamless
	logo_c = Vector2(vs.x * 0.5, vs.y * 0.19)
	pres_c = Vector2(vs.x * 0.5, vs.y * 0.382)
	tex_bg = load(UI % BACKDROP)
	tex_hole = load(UI % HOLE)
	tex_logo = load(UI % "brand_logo.png")
	tex_pres = load(UI % "brand_presents.png")
	tex_ring = load(UI % "fx_ring.png")
	tex_spark = load(UI % "fx_sparkle.png")
	fx_layer = Control.new()
	fx_layer.size = vs
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx_layer.material = add_mat
	fx_layer.draw.connect(_draw_fx)
	add_child(fx_layer)
	var stream := load("res://assets/audio/brand_sting.ogg") as AudioStream
	if stream != null:
		sting = AudioStreamPlayer.new()
		sting.stream = stream
		sting.volume_db = -3.0
		add_child(sting)
		sting.play()
	create_tween().tween_property(self, "fade_in", 1.0, 0.45)
	create_tween().tween_property(self, "hole_scale", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)


func _burst(pos: Vector2, n: int, speed: float, life: float = 0.8) -> void:
	for k in n:
		sparks.append({"p": pos, "v": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(speed * 0.4, speed),
			"life": life * rng.randf_range(0.7, 1.2), "age": 0.0, "s": rng.randf_range(0.12, 0.3), "r": rng.randf() * TAU})


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	pulse = maxf(0.0, pulse - delta * 3.0)
	flash = maxf(0.0, flash - delta * 1.8)
	shake = maxf(0.0, shake - delta * 2.6)
	position = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake * 8.0
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
	if not logo_started and t >= LOGO_AT:
		logo_started = true
		flash = 1.0
		pulse = 1.0
		shake = 0.8
		_burst(hole_c, 40, 560.0, 0.9)
		create_tween().tween_property(self, "logo_p", 1.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not pres_started and t >= PRESENTS_AT:
		pres_started = true
		_burst(pres_c, 12, 200.0, 0.7)
		create_tween().tween_property(self, "pres_p", 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not swallowed and t >= SWALLOW_AT:
		swallowed = true
		var tw := create_tween()
		tw.tween_property(self, "swallow_p", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			pulse = 1.0
			flash = 0.8
			shake = 0.5
			_burst(hole_c, 22, 420.0, 0.6))
	if t >= END_AT:
		_finish()
	fx_layer.queue_redraw()
	queue_redraw()


func _input(e: InputEvent) -> void:
	if done or t < 1.0:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if done:
		return
	done = true
	position = Vector2.ZERO
	if sting != null:
		var fade := create_tween()
		fade.tween_property(sting, "volume_db", -40.0, 0.25)
	finished.emit()
	hide()   # keep the node alive just long enough for the sting to ring out
	get_tree().create_timer(0.5).timeout.connect(queue_free)


func _tex(tex: Texture2D, center: Vector2, sz: Vector2, rot: float = 0.0, col: Color = Color.WHITE) -> void:
	draw_set_transform(center, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	# game skyline backdrop (matches the game intro that follows)
	draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	draw_texture_rect(tex_bg, Rect2(Vector2.ZERO, vs), false, Color(1, 1, 1, fade_in))
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.04, 0.16, 0.6 * fade_in))
	if logo_started:
		for k in 5:   # soft dark halo behind the studio logo so it reads on the busy skyline
			draw_circle(Vector2(vs.x * 0.5, (logo_c.y + pres_c.y) * 0.5), 250.0 - float(k) * 36.0, Color(0.02, 0.03, 0.12, 0.12 * clampf(logo_p, 0.0, 1.0) * (1.0 - swallow_p)))
	for k in 6:
		var rr := (300.0 - float(k) * 40.0) * hole_scale * (1.0 + 0.12 * pulse)
		draw_circle(hole_c, rr, Color(1.0, 0.8, 0.2, 0.04 + flash * 0.05))
	var hs := 330.0 * hole_scale * (1.0 + 0.1 * pulse)
	if hs > 2.0:
		_tex(tex_hole, hole_c, Vector2(hs, hs), t * 0.9)
	# studio logo rises out of the hole, then is swallowed again
	if logo_started:
		var lh := 235.0
		var lw := lh * float(tex_logo.get_width()) / float(tex_logo.get_height())
		var rise := clampf(logo_p, 0.0, 1.15)
		var pos := hole_c.lerp(logo_c, rise).lerp(hole_c, swallow_p)
		var sc := maxf(logo_p, 0.0) * (1.0 - swallow_p * 0.95)
		var wob := 1.0 + 0.02 * sin((t - LOGO_AT) * 3.0) * clampf(logo_p, 0.0, 1.0)
		_tex(tex_logo, pos, Vector2(lw, lh) * sc * wob, swallow_p * 4.0, Color(1, 1, 1, clampf(logo_p * 2.0, 0.0, 1.0) * (1.0 - swallow_p * 0.7)))
	if pres_started:
		var pw := 270.0
		var ph := pw * float(tex_pres.get_height()) / float(tex_pres.get_width())
		var ppos := pres_c.lerp(hole_c, swallow_p) + Vector2(0, 14.0 * (1.0 - pres_p))
		_tex(tex_pres, ppos, Vector2(pw, ph) * (1.0 - swallow_p * 0.95), swallow_p * -3.0, Color(1, 1, 1, clampf(pres_p, 0.0, 1.0) * (1.0 - swallow_p)))
	if flash > 0.0:
		var rs := 260.0 + 1000.0 * (1.0 - flash)
		_tex(tex_ring, hole_c, Vector2(rs, rs), 0.0, Color(1, 1, 1, flash))
	for s in sparks:
		var a := 1.0 - float(s["age"]) / float(s["life"])
		var ss := 150.0 * float(s["s"]) * (0.4 + 0.6 * a)
		_tex(tex_spark, s["p"], Vector2(ss, ss), float(s["r"]) + float(s["age"]) * 4.0, Color(1, 1, 1, a))


func _draw_fx() -> void:
	var a := 0.07 * hole_scale + 0.06 * pulse + flash * 0.16
	for k in 14:
		var a0 := float(k) / 14.0 * TAU + t * 0.35
		var a1 := a0 + TAU / 14.0 * 0.45
		fx_layer.draw_colored_polygon(PackedVector2Array([hole_c, hole_c + Vector2.from_angle(a0) * 1100.0, hole_c + Vector2.from_angle(a1) * 1100.0]), Color(1.0, 0.8, 0.3, a))
	if flash > 0.0:
		var fs := 900.0 * flash + 200.0
		fx_layer.draw_set_transform(hole_c, t * 0.5, Vector2.ONE)
		fx_layer.draw_texture_rect(tex_spark, Rect2(-Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false, Color(1, 0.9, 0.6, flash))
		fx_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
