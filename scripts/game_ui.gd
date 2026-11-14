class_name GameUI
extends CanvasLayer
## Every screen: home, HUD, daily reward, skins, missions, upgrades, settings,
## pause, countdown, result (with bonus meter) and the touch joystick.

signal play_pressed(mode: String)
signal again_pressed
signal home_pressed
signal pause_toggled(paused: bool)
signal bonus_claimed(mult: int)
signal settings_changed
signal skin_changed
signal sound(name: String)
signal double_requested
signal boost_requested
signal revive_choice(accept: bool)
signal intro_done

const GOLD := Color(1.0, 0.85, 0.25)
const GREEN := Color(0.16, 0.7, 0.36)
const BLUE := Color(0.2, 0.38, 0.72)
const RED := Color(0.85, 0.28, 0.3)
const PANEL := Color(0.08, 0.11, 0.22, 0.96)
const UPGRADES := [
	["speed", "Speed", "+6% move speed"],
	["size", "Start Size", "bigger hole at start"],
	["growth", "Growth", "+8% growth per item"],
	["time", "Round Time", "+5 seconds"],
]

class Joy extends Control:
	var active := false
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	func _draw() -> void:
		if not active:
			return
		draw_circle(a, 110.0, Color(1, 1, 1, 0.10))
		draw_arc(a, 110.0, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
		draw_circle(b, 44.0, Color(1, 1, 1, 0.55))

class Meter extends Control:
	var running := false
	var t := 0.0
	func _process(d: float) -> void:
		if running:
			t += d * 2.2
			queue_redraw()
	func pos() -> float:
		return 0.5 + 0.5 * sin(t)
	func mult() -> int:
		var dd := absf(pos() - 0.5)
		if dd < 0.08:
			return 5
		if dd < 0.22:
			return 3
		return 2
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var zones := [[0.0, 0.28, Color(0.35, 0.55, 0.9), "x2"], [0.28, 0.42, Color(0.3, 0.8, 0.4), "x3"],
			[0.42, 0.58, Color(1.0, 0.7, 0.15), "x5"], [0.58, 0.72, Color(0.3, 0.8, 0.4), "x3"], [0.72, 1.0, Color(0.35, 0.55, 0.9), "x2"]]
		for z in zones:
			draw_rect(Rect2(w * float(z[0]), 0, w * (float(z[1]) - float(z[0])), h), z[2])
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(w * (float(z[0]) + float(z[1])) * 0.5 - 14.0, h * 0.68), str(z[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0, 0, 0, 0.75))
		var x := w * pos()
		draw_rect(Rect2(x - 5.0, -10.0, 10.0, h + 20.0), Color.WHITE)

var profile: Profile
var mon: Monetization
var intro_active: bool = false
var boost_btn: Button
var pass_btn: Button
var res_double_btn: Button
var joy: Joy
var hud: Control
var home: Control
var result: Control
var pause_root: Control
var modal: Control

var score_lbl: Label
var level_lbl: Label
var timer_lbl: Label
var combo_lbl: Label
var toast_lbl: Label
var hint_lbl: Label
var power_lbl: Label
var count_lbl: Label
var board_lbls: Array[Label] = []
var pause_btn: Button
var minimap: Minimap
var danger_rect: TextureRect
var confetti: CPUParticles2D
var toast_tween: Tween

var home_level: Label
var home_theme: Label
var home_coins: Label
var home_xp: ProgressBar
var home_plevel: Label
var royale_btn: Button
var mission_btn: Button
var title_lbl: Control
var play_btn: Button

var res_head: Label
var res_info: Label
var res_near: Label
var res_board: Label
var res_xp: ProgressBar
var res_bonus_box: Control
var res_meter: Meter
var res_bonus_btn: Button
var res_bonus_lbl: Label
var res_buttons: Control
var res_gain: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	joy = Joy.new()
	joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joy)
	_build_hud()
	_build_home()
	_build_result()
	_build_pause()
	show_home()


# =====================================================================
# helpers
# =====================================================================
func _label(parent: Node, text: String, size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


# ---- glossy 3D button textures (generated once, tinted per button) ----
static var _btn_tex: Dictionary = {}


static func _rr_dist(px: float, py: float, x0: float, y0: float, x1: float, y1: float, r: float) -> float:
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var hx := (x1 - x0) * 0.5 - r
	var hy := (y1 - y0) * 0.5 - r
	var qx := maxf(absf(px - cx) - hx, 0.0)
	var qy := maxf(absf(py - cy) - hy, 0.0)
	return sqrt(qx * qx + qy * qy) - r


## kind: "normal" | "pressed". White-based so modulate_color tints it.
static func _make_button_texture(kind: String) -> ImageTexture:
	if _btn_tex.has(kind):
		return _btn_tex[kind]
	var W := 160
	var H := 120
	var R := 36.0
	var lip := 18.0 if kind == "normal" else 6.0
	var off := 0.0 if kind == "normal" else 12.0
	var shade := 1.0 if kind == "normal" else 0.88
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var fy0 := 6.0 + off
	var fy1 := float(H) - lip - 2.0 + off
	for y in H:
		for x in W:
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var d_out := _rr_dist(px, py, 1.5, 1.5, W - 1.5, H - 1.5, R)
			var a := clampf(0.5 - d_out, 0.0, 1.0)
			if a <= 0.0:
				continue
			# default: dark outline
			var c := Color(0.05, 0.06, 0.16)
			if d_out < -4.0:
				# the 3D "lip" under the face
				c = Color(0.52, 0.52, 0.56) * shade
				c.a = 1.0
			var d_face := _rr_dist(px, py, 6.0, fy0, W - 6.0, fy1, R - 4.0)
			if d_face < 0.5 and d_out < -3.0:
				var t := clampf((py - fy0) / maxf(fy1 - fy0, 1.0), 0.0, 1.0)
				var g := lerpf(1.0, 0.80, t) * shade
				if t < 0.46:
					g += 0.20 * (1.0 - t / 0.46) * shade     # glossy highlight on the top half
				if py - fy0 < 3.5:
					g += 0.18                                 # bright top rim
				if d_face > -3.0 and t > 0.55:
					g -= 0.10                                 # soft inner shade near the bottom edge
				var fc := Color(g, g, g)
				var fa := clampf(0.5 - d_face, 0.0, 1.0)
				c = c.lerp(fc, fa)
			c.a = a
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_btn_tex[kind] = tex
	return tex


func _tex_style(kind: String, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _make_button_texture(kind)
	sb.texture_margin_left = 44.0
	sb.texture_margin_right = 44.0
	sb.texture_margin_top = 36.0
	sb.texture_margin_bottom = 44.0
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 8.0 if kind == "normal" else 16.0
	sb.content_margin_bottom = 20.0 if kind == "normal" else 12.0
	sb.modulate_color = tint
	return sb


func _style(col: Color, radius: int = 28) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 6
	s.border_width_bottom = 6
	s.border_color = col.darkened(0.35)
	return s


static func icon_tex(name: String) -> Texture2D:
	return load("res://assets/ui/%s.png" % name) as Texture2D


func _button(parent: Node, text: String, size: int, col: Color, min_size: Vector2, icon: String = "", icon_px: int = 52) -> Button:
	var b := Button.new()
	if icon != "":
		b.icon = icon_tex(icon)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", icon_px)
		b.add_theme_constant_override("h_separation", 10)
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.18, 0.95))
	b.add_theme_constant_override("outline_size", 9)
	var sat := col.lerp(Color.WHITE, 0.08)
	b.add_theme_stylebox_override("normal", _tex_style("normal", sat))
	b.add_theme_stylebox_override("hover", _tex_style("normal", sat.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _tex_style("pressed", sat.darkened(0.12)))
	b.add_theme_stylebox_override("disabled", _tex_style("normal", Color(col.r, col.g, col.b).darkened(0.55)))
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	b.add_theme_constant_override("shadow_offset_y", 3)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		create_tween().tween_property(b, "scale", Vector2(0.93, 0.93), 0.06))
	b.button_up.connect(func():
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK))
	b.pressed.connect(func(): sound.emit("click"))
	parent.add_child(b)
	return b


func _bar(parent: Node, w: float, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, 24)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(12)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b


func _panel_box(col: Color = PANEL) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(32)
	s.content_margin_left = 36
	s.content_margin_right = 36
	s.content_margin_top = 30
	s.content_margin_bottom = 30
	s.border_width_left = 3
	s.border_width_right = 3
	s.border_width_top = 3
	s.border_width_bottom = 3
	s.border_color = Color(1, 1, 1, 0.12)
	return s


func _full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)


func _spacer(parent: Node, h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)
	return s


# =====================================================================
# HUD
# =====================================================================
func _build_hud() -> void:
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 0, 0, 0), Color(1, 0, 0, 0), Color(1, 0.05, 0.05, 0.85)])
	gr.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	danger_rect = TextureRect.new()
	danger_rect.texture = gt
	danger_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	danger_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_full_rect(danger_rect)
	danger_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_rect.modulate.a = 0.0
	add_child(danger_rect)

	hud = MarginContainer.new()
	_full_rect(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_constant_override("margin_left", 24)
	hud.add_theme_constant_override("margin_right", 24)
	hud.add_theme_constant_override("margin_top", 16)
	hud.add_theme_constant_override("margin_bottom", 24)
	add_child(hud)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vb)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left)
	score_lbl = _label(left, "0", 48, GOLD)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_lbl = _label(left, "Level 1", 28, Color(0.8, 0.9, 1))
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pause_btn = _button(left, "", 30, Color(0.2, 0.25, 0.4, 0.9), Vector2(76, 60), "icon_pause", 40)
	pause_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pause_btn.pressed.connect(func(): _set_pause(true))

	timer_lbl = _label(top, "1:30", 58)
	timer_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	timer_lbl.resized.connect(func(): timer_lbl.pivot_offset = timer_lbl.size * 0.5)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right)
	for i in 4:
		var l := _label(right, "", 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		board_lbls.append(l)
	minimap = Minimap.new()
	right.add_child(minimap)

	hint_lbl = _label(vb, "", 34, Color(1, 1, 0.7))
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_spacer(vb, 20)
	combo_lbl = _label(vb, "", 56, Color(1, 0.6, 0.15))
	combo_lbl.resized.connect(func(): combo_lbl.pivot_offset = combo_lbl.size * 0.5)
	toast_lbl = _label(vb, "", 38)
	_spacer(vb, 0).size_flags_vertical = Control.SIZE_EXPAND_FILL
	power_lbl = _label(vb, "", 32, Color(0.6, 1, 0.9))

	count_lbl = _label(self, "", 200, Color(1, 0.95, 0.5))
	count_lbl.set_anchors_preset(Control.PRESET_CENTER)
	count_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	count_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	count_lbl.add_theme_constant_override("outline_size", 24)
	count_lbl.modulate.a = 0.0
	count_lbl.resized.connect(func(): count_lbl.pivot_offset = count_lbl.size * 0.5)


func update_minimap(dots: Array, zone: float) -> void:
	minimap.set_data(dots, zone)


func update_hud(score: int, time_left: float, subtitle: String, combo: int, mult: int, board: Array, powers: String, clock: float) -> void:
	score_lbl.text = str(score)
	level_lbl.text = subtitle
	var t := maxi(0, int(ceil(time_left)))
	timer_lbl.text = "%d:%02d" % [t / 60, t % 60]
	if t <= 10:
		timer_lbl.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
		var s := 1.0 + 0.18 * absf(sin(clock * 6.0))
		timer_lbl.scale = Vector2(s, s)
	else:
		timer_lbl.add_theme_color_override("font_color", Color.WHITE)
		timer_lbl.scale = Vector2.ONE
	if combo >= 3:
		combo_lbl.text = "COMBO x%d" % mult
		var cs := 1.0 + 0.06 * sin(clock * 12.0)
		combo_lbl.scale = Vector2(cs, cs)
	else:
		combo_lbl.text = ""
	for i in board_lbls.size():
		if i < board.size():
			var e: Array = board[i]
			board_lbls[i].text = "%d. %s  %d" % [i + 1, e[0], e[1]]
			board_lbls[i].add_theme_color_override("font_color", GOLD if e[2] else Color(1, 1, 1, 0.85))
		else:
			board_lbls[i].text = ""
	power_lbl.text = powers


func toast(text: String, col: Color = Color.WHITE) -> void:
	toast_lbl.text = text
	toast_lbl.add_theme_color_override("font_color", col)
	toast_lbl.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.4)
	toast_tween.tween_property(toast_lbl, "modulate:a", 0.0, 0.5)


func set_danger(amount: float, clock: float) -> void:
	danger_rect.modulate.a = clampf(amount * 1.4, 0.0, 1.0) * (0.65 + 0.35 * sin(clock * 10.0))


## Short message that works on any screen (home, HUD, result).
func flash(text: String) -> void:
	toast(text, Color(1, 0.85, 0.4))
	home_theme.text = text
	get_tree().create_timer(2.5, true).timeout.connect(func():
		if home.visible and home_theme.text == text:
			settings_changed.emit())   # main refreshes the home screen -> theme name returns


func set_hint(text: String) -> void:
	hint_lbl.text = text


func show_count(text: String) -> void:
	count_lbl.text = text
	count_lbl.modulate.a = 1.0
	count_lbl.scale = Vector2(1.8, 1.8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(count_lbl, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(count_lbl, "modulate:a", 0.0, 0.4).set_delay(0.45)


func set_joystick(active: bool, a: Vector2, b: Vector2) -> void:
	joy.active = active
	joy.a = a
	joy.b = b
	joy.queue_redraw()


func get_pause_rect() -> Rect2:
	return pause_btn.get_global_rect().grow(20.0)


# =====================================================================
# Pause
# =====================================================================
func _build_pause() -> void:
	pause_root = Control.new()
	_full_rect(pause_root)
	add_child(pause_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_full_rect(dim)
	pause_root.add_child(dim)
	var cc := CenterContainer.new()
	_full_rect(cc)
	pause_root.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	cc.add_child(vb)
	_label(vb, "PAUSED", 84).add_theme_font_override("font", Fonts.title())
	var r := _button(vb, "RESUME", 58, GREEN, Vector2(440, 110))
	r.pressed.connect(func(): _set_pause(false))
	var h := _button(vb, "QUIT TO HOME", 44, RED, Vector2(440, 90))
	h.pressed.connect(func():
		_set_pause(false)
		home_pressed.emit())
	pause_root.visible = false


func _set_pause(p: bool) -> void:
	pause_root.visible = p
	pause_toggled.emit(p)


# =====================================================================
# Home
# =====================================================================
func _build_home() -> void:
	home = Control.new()
	_full_rect(home)
	add_child(home)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.12, 0.45)
	_full_rect(dim)
	home.add_child(dim)

	var m := MarginContainer.new()
	_full_rect(m)
	m.add_theme_constant_override("margin_left", 36)
	m.add_theme_constant_override("margin_right", 36)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 24)
	home.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)

	# top bar: profile level + coins
	var top := HBoxContainer.new()
	vb.add_child(top)
	var pl := VBoxContainer.new()
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(pl)
	home_plevel = _label(pl, "Lv 1", 32, Color(0.7, 0.9, 1))
	home_plevel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	home_xp = _bar(pl, 240, Color(0.3, 0.85, 1.0))
	home_xp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var coin_icon := TextureRect.new()
	coin_icon.texture = icon_tex("icon_coin")
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.custom_minimum_size = Vector2(54, 54)
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(coin_icon)
	home_coins = _label(top, "0", 42, GOLD)
	home_coins.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# two columns: title on the left, buttons on the right
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 30)
	vb.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var logo := TextureRect.new()
	logo.texture = icon_tex("intro_logo")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(520, 195)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(logo)
	title_lbl = logo
	logo.resized.connect(func(): logo.pivot_offset = logo.size * 0.5)
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.035, 1.035), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "scale", Vector2(0.985, 0.985), 0.9).set_trans(Tween.TRANS_SINE)
	home_level = _label(left, "Level 1", 46, Color(0.85, 0.95, 1))
	home_theme = _label(left, "", 28, Color(1, 1, 1, 0.75))
	boost_btn = _button(left, "FREE BOOST  (watch ad)", 26, Color(0.15, 0.55, 0.65), Vector2(400, 72), "icon_ad", 48)
	boost_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boost_btn.pressed.connect(func(): boost_requested.emit())

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)
	play_btn = _button(right, "PLAY", 72, GREEN, Vector2(500, 128), "icon_play", 92)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.pressed.connect(func(): play_pressed.emit("classic"))
	play_btn.resized.connect(func(): play_btn.pivot_offset = play_btn.size * 0.5)
	var pt := play_btn.create_tween().set_loops()
	pt.tween_property(play_btn, "scale", Vector2(1.05, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
	pt.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	royale_btn = _button(right, "ROYALE", 42, Color(0.75, 0.2, 0.55), Vector2(500, 88), "icon_royale", 64)
	royale_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	royale_btn.pressed.connect(func(): play_pressed.emit("royale"))
	var nav := GridContainer.new()
	nav.columns = 2
	nav.add_theme_constant_override("h_separation", 12)
	nav.add_theme_constant_override("v_separation", 12)
	nav.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(nav)
	var b1 := _button(nav, "SKINS", 26, Color(0.55, 0.3, 0.8), Vector2(244, 78), "icon_skins")
	b1.pressed.connect(_panel_skins)
	mission_btn = _button(nav, "MISSIONS", 24, Color(0.9, 0.5, 0.15), Vector2(244, 78), "icon_missions")
	mission_btn.pressed.connect(_panel_missions)
	var b3 := _button(nav, "UPGRADE", 26, BLUE, Vector2(244, 78), "icon_upgrade")
	b3.pressed.connect(_panel_upgrades)
	var b4 := _button(nav, "SETTINGS", 24, Color(0.35, 0.4, 0.5), Vector2(244, 78), "icon_settings")
	b4.pressed.connect(_panel_settings)
	var b5 := _button(nav, "SHOP", 28, Color(0.85, 0.65, 0.1), Vector2(244, 78), "icon_shop")
	b5.pressed.connect(_panel_shop)
	pass_btn = _button(nav, "PRO PASS", 26, Color(0.2, 0.7, 0.55), Vector2(244, 78), "icon_pass")
	pass_btn.pressed.connect(_panel_pass)


func refresh_home(theme_name: String) -> void:
	home_level.text = "Level %d" % profile.level
	home_theme.text = theme_name
	home_coins.text = ("VIP   " if profile.vip else "") + "%d coins" % profile.coins
	boost_btn.visible = not profile.vip
	boost_btn.disabled = profile.boost_ready
	boost_btn.text = "BOOST READY!" if profile.boost_ready else "FREE BOOST  (watch ad)"
	boost_btn.visible = not profile.vip and mon != null and mon.rewarded_available()
	pass_btn.text = "PRO PASS" if profile.pass_tier() <= 0 else "PASS  TIER %d" % profile.pass_tier()
	home_plevel.text = "Lv %d" % profile.plevel
	home_xp.max_value = profile.xp_needed()
	home_xp.value = profile.xp
	var unlocked := profile.level >= 3
	royale_btn.text = "ROYALE" if unlocked else "ROYALE  (Level 3)"
	royale_btn.disabled = not unlocked
	var c := profile.claimable_count()
	mission_btn.text = "MISSIONS (%d!)" % c if c > 0 else "MISSIONS"


# =====================================================================
# Modals
# =====================================================================
var modal_outer: VBoxContainer


func _open_modal(title: String) -> VBoxContainer:
	_close_modal(false)
	sound.emit("whoosh")
	modal = Control.new()
	_full_rect(modal)
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	_full_rect(dim)
	modal.add_child(dim)
	var cc := CenterContainer.new()
	_full_rect(cc)
	modal.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _panel_box())
	cc.add_child(pc)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	pc.add_child(outer)
	_label(outer, title, 46, GOLD)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(880, 400)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	modal_outer = outer
	pc.scale = Vector2(0.85, 0.85)
	pc.resized.connect(func(): pc.pivot_offset = pc.size * 0.5)
	create_tween().tween_property(pc, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return content


func _close_modal(refresh: bool = true) -> void:
	if modal != null:
		modal.queue_free()
		modal = null
	if refresh and home.visible:
		settings_changed.emit()


func _add_close(_content: VBoxContainer, text: String = "CLOSE") -> void:
	var b := _button(modal_outer, text, 36, Color(0.35, 0.4, 0.5), Vector2(260, 68))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): _close_modal())


func _panel_upgrades() -> void:
	var vb := _open_modal("UPGRADES")
	_label(vb, "%d coins" % profile.coins, 38, Color.WHITE)
	for d in UPGRADES:
		var id: String = d[0]
		var lv: int = profile.upg[id]
		var b := _button(vb, "", 26, BLUE, Vector2(780, 84))
		if lv >= Profile.MAX_LVL:
			b.text = "%s   Lv %d   MAX\n%s" % [d[1], lv, d[2]]
			b.disabled = true
		else:
			var cost := profile.upgrade_cost(id)
			b.text = "%s   Lv %d   -   %d coins\n%s" % [d[1], lv, cost, d[2]]
			b.disabled = profile.coins < cost
		b.pressed.connect(func():
			var c := profile.upgrade_cost(id)
			if profile.coins >= c and int(profile.upg[id]) < Profile.MAX_LVL:
				profile.coins -= c
				profile.upg[id] = int(profile.upg[id]) + 1
				profile.save_all()
				sound.emit("coin")
				_panel_upgrades())
	_add_close(vb)


func _panel_skins() -> void:
	var vb := _open_modal("HOLE SKINS")
	_label(vb, "%d coins" % profile.coins, 38, Color.WHITE)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)
	for i in Profile.SKINS.size():
		var sk: Dictionary = Profile.SKINS[i]
		var col: Color = sk["color"]
		if sk.has("rainbow"):
			col = Color(0.5, 0.3, 0.9)
		var owned := profile.owned.has(i)
		var status := ""
		if profile.skin == i:
			status = "EQUIPPED"
		elif owned:
			status = "OWNED"
		elif int(sk["cost"]) < 0:
			status = "PRO PASS ONLY"
		else:
			status = "%d coins" % int(sk["cost"])
		var b := _button(grid, "%s\n%s" % [sk["name"], status], 26, col.darkened(0.25), Vector2(280, 100), "skin_%d" % i, 76)
		if not owned:
			b.icon = icon_tex("icon_lock") if int(sk["cost"]) < 0 else icon_tex("skin_%d" % i)
		if not owned and (int(sk["cost"]) < 0 or profile.coins < int(sk["cost"])):
			b.modulate = Color(1, 1, 1, 0.6)
		b.pressed.connect(func():
			if profile.owned.has(i):
				profile.skin = i
				profile.save_all()
				skin_changed.emit()
				_panel_skins()
			elif int(sk["cost"]) >= 0 and profile.coins >= int(sk["cost"]):
				profile.coins -= int(sk["cost"])
				profile.owned.append(i)
				profile.skin = i
				profile.save_all()
				sound.emit("levelup")
				skin_changed.emit()
				_panel_skins()
			else:
				sound.emit("error"))
	_add_close(vb)


func _panel_missions() -> void:
	var vb := _open_modal("DAILY MISSIONS")
	for i in profile.missions.size():
		var m: Dictionary = profile.missions[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		vb.add_child(row)
		var l := _label(row, "%s\n%d / %d" % [m["text"], int(m["prog"]), int(m["target"])], 28)
		l.custom_minimum_size = Vector2(560, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var done: bool = int(m["prog"]) >= int(m["target"])
		var b := _button(row, "", 28, GREEN if done and not m["claimed"] else Color(0.3, 0.33, 0.45), Vector2(190, 84))
		if m["claimed"]:
			b.text = "DONE"
			b.disabled = true
		elif done:
			b.text = "+%d" % int(m["reward"])
		else:
			b.text = "%d coins" % int(m["reward"])
			b.disabled = true
		b.pressed.connect(func():
			if profile.claim_mission(i) > 0:
				sound.emit("coin")
				_panel_missions())
	_label(vb, "New missions every day", 26, Color(1, 1, 1, 0.6))
	_add_close(vb)


func _panel_settings() -> void:
	var vb := _open_modal("SETTINGS")
	var defs := [["Music", "music_on"], ["Sound FX", "sfx_on"], ["Vibration", "vib_on"]]
	for d in defs:
		var key: String = d[1]
		var on: bool = profile.get(key)
		var ic := "icon_music_on" if key == "music_on" else ("icon_sound_on" if key == "sfx_on" else "icon_vibrate")
		if not on and key != "vib_on":
			ic = ic.replace("_on", "_off")
		var b := _button(vb, "%s: %s" % [d[0], "ON" if on else "OFF"], 40, GREEN if on else RED, Vector2(520, 90), ic, 64)
		b.pressed.connect(func():
			profile.set(key, not bool(profile.get(key)))
			profile.save_all()
			settings_changed.emit()
			_panel_settings())
	_label(vb, "Best score: %d   Wins: %d" % [profile.best, profile.wins], 30, Color(1, 1, 1, 0.8))
	_add_close(vb)


func mark_double_done(extra: int) -> void:
	res_double_btn.text = "DOUBLED!  +%d" % extra
	res_double_btn.disabled = true


func _product_row(vb: VBoxContainer, id: String, col: Color) -> void:
	var p: Dictionary = mon.PRODUCTS[id]
	var owned_now := (id == "remove_ads" and profile.no_ads) or (id == "vip" and profile.vip) \
		or (id == "pass_premium" and profile.pass_premium) or (id == "starter" and profile.starter_bought)
	var txt := "%s   -   %s" % [p["name"], p["price"]]
	if str(p["desc"]) != "":
		txt += "\n" + str(p["desc"])
	var b := _button(vb, "OWNED:  " + str(p["name"]) if owned_now else txt, 24, col, Vector2(800, 84))
	b.disabled = owned_now or not mon.store_available()
	b.pressed.connect(func():
		mon.buy(id, func(ok: bool):
			sound.emit("coin" if ok else "error")
			_panel_shop()))


func _panel_shop() -> void:
	var vb := _open_modal("SHOP")
	if mon.test_mode:
		_label(vb, "TEST MODE - purchases are free in debug builds", 24, Color(1, 0.6, 0.3))
	elif not mon.store_available():
		_label(vb, "Store coming soon", 28, Color(1, 1, 1, 0.7))
	if profile.is_starter_available():
		var hrs := profile.starter_seconds_left() / 3600
		_label(vb, "ONE-TIME OFFER - ends in %d hours" % hrs, 26, Color(1, 0.85, 0.3))
		_product_row(vb, "starter", Color(0.85, 0.4, 0.1))
	_product_row(vb, "vip", Color(0.55, 0.3, 0.8))
	_product_row(vb, "pass_premium", Color(0.2, 0.6, 0.5))
	_product_row(vb, "remove_ads", Color(0.2, 0.38, 0.72))
	_label(vb, "COINS", 30, GOLD)
	_product_row(vb, "coins_s", Color(0.3, 0.4, 0.55))
	_product_row(vb, "coins_m", Color(0.3, 0.45, 0.6))
	_product_row(vb, "coins_l", Color(0.3, 0.5, 0.65))
	_add_close(vb)


func _panel_pass() -> void:
	var vb := _open_modal("PRO PASS")
	var tier := profile.pass_tier()
	var into := profile.pass_xp - tier * Profile.PASS_XP_PER_TIER if tier < Profile.PASS_TIERS else Profile.PASS_XP_PER_TIER
	_label(vb, "Tier %d / %d     (play rounds to earn XP)" % [tier, Profile.PASS_TIERS], 28, Color.WHITE)
	var bar := _bar(vb, 700, Color(0.2, 0.8, 0.6))
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.max_value = Profile.PASS_XP_PER_TIER
	bar.value = into
	if not profile.pass_premium:
		var ub := _button(vb, "UNLOCK PREMIUM LANE  -  $4.99", 30, Color(0.2, 0.7, 0.55), Vector2(700, 70))
		ub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ub.disabled = not mon.store_available()
		ub.pressed.connect(func():
			mon.buy("pass_premium", func(ok: bool):
				sound.emit("levelup" if ok else "error")
				_panel_pass()))
	for t in range(1, Profile.PASS_TIERS + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vb.add_child(row)
		var tl := _label(row, "T%d" % t, 28, GOLD if t <= tier else Color(1, 1, 1, 0.5))
		tl.custom_minimum_size = Vector2(70, 0)
		for prem in [false, true]:
			var r := profile.pass_reward(t, prem)
			var txt := ("PRO  " if prem else "") + profile.pass_reward_text(r)
			var can := profile.pass_can_claim(t, prem)
			var claimed := profile.pass_is_claimed(t, prem)
			var col := Color(0.25, 0.3, 0.45)
			if can:
				col = GREEN
			elif prem:
				col = Color(0.4, 0.3, 0.1)
			var b := _button(row, "CLAIMED" if claimed else txt, 24, col, Vector2(340, 62))
			b.disabled = not can
			if not claimed and not can and t > tier:
				b.text = txt + "  (locked)"
			elif not claimed and prem and not profile.pass_premium and t <= tier:
				b.text = txt + "  (premium)"
			var tt := t
			var pp: bool = prem
			b.pressed.connect(func():
				if profile.claim_pass(tt, pp):
					sound.emit("coin")
					_panel_pass())
	_add_close(vb)


## Royale elimination: offer a revive (rewarded ad).
## Opening animation, shown once per app launch.
func play_intro() -> void:
	intro_active = true
	home.visible = false
	var brand := BrandIntro.new()
	add_child(brand)
	brand.finished.connect(func():
		var intro := Intro.new()
		intro.warm = true
		add_child(intro)
		intro.hit.connect(func(n: String): sound.emit(n))
		intro.finished.connect(func():
			intro_active = false
			home.visible = true
			home.modulate.a = 0.0
			create_tween().tween_property(home, "modulate:a", 1.0, 0.8).set_delay(0.1)
			intro_done.emit()))


func show_revive() -> void:
	var vb := _open_modal("YOU WERE ELIMINATED!")
	_label(vb, "Watch a short ad to jump back in with 3 seconds of protection.", 26, Color.WHITE)
	var yes := _button(vb, "REVIVE  (watch ad)", 44, GREEN, Vector2(560, 100))
	yes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	yes.pressed.connect(func():
		_close_modal(false)
		revive_choice.emit(true))
	var no := _button(vb, "NO THANKS", 30, Color(0.35, 0.4, 0.5), Vector2(300, 66))
	no.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	no.pressed.connect(func():
		_close_modal(false)
		revive_choice.emit(false))


func close_revive() -> void:
	_close_modal(false)


func show_starter() -> void:
	if not profile.is_starter_available():
		return
	var vb := _open_modal("STARTER PACK")
	_label(vb, "ONE-TIME OFFER", 30, Color(1, 0.85, 0.3))
	_label(vb, "1000 coins  +  Lava skin  +  free boost", 34, Color.WHITE)
	_label(vb, "Ends in %d hours" % (profile.starter_seconds_left() / 3600), 26, Color(1, 1, 1, 0.7))
	var b := _button(vb, "GET IT  -  $1.99", 48, GREEN, Vector2(520, 96))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.disabled = not mon.store_available()
	b.pressed.connect(func():
		mon.buy("starter", func(ok: bool):
			sound.emit("levelup" if ok else "error")
			_close_modal()))
	_add_close(vb, "MAYBE LATER")


func show_daily() -> void:
	var st := profile.daily_status()
	if not st["available"]:
		return
	var vb := _open_modal("DAILY REWARD")
	_label(vb, "Come back every day for bigger rewards!", 28, Color(1, 1, 1, 0.8))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for i in Profile.DAILY.size():
		var pc := PanelContainer.new()
		var col := Color(0.2, 0.25, 0.4)
		if i < int(st["index"]):
			col = Color(0.2, 0.5, 0.3)
		elif i == int(st["index"]):
			col = Color(0.85, 0.6, 0.1)
		pc.add_theme_stylebox_override("panel", _style(col, 20))
		pc.custom_minimum_size = Vector2(112, 110)
		grid.add_child(pc)
		_label(pc, "Day %d\n+%d" % [i + 1, Profile.DAILY[i]], 24)
	var b := _button(vb, "CLAIM +%d" % int(st["reward"]), 48, GREEN, Vector2(440, 96))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		var got := profile.claim_daily()
		if got > 0:
			sound.emit("coin")
		_close_modal())


# =====================================================================
# Result
# =====================================================================
func _build_result() -> void:
	result = Control.new()
	_full_rect(result)
	add_child(result)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.12, 0.72)
	_full_rect(dim)
	result.add_child(dim)
	var cc := CenterContainer.new()
	_full_rect(cc)
	result.add_child(cc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 70)
	cc.add_child(hb)

	# left column: headline, rewards, ranking
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	hb.add_child(left)
	res_head = _label(left, "", 78, GOLD)
	res_head.add_theme_font_override("font", Fonts.title())
	res_head.add_theme_constant_override("outline_size", 14)
	res_head.resized.connect(func(): res_head.pivot_offset = res_head.size * 0.5)
	res_info = _label(left, "", 34)
	res_near = _label(left, "", 28, Color(1, 0.8, 0.5))
	res_xp = _bar(left, 420, Color(0.3, 0.85, 1.0))
	res_xp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	res_board = _label(left, "", 28, Color(0.85, 0.95, 1))

	# right column: bonus meter + buttons
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(right)
	res_bonus_box = VBoxContainer.new()
	res_bonus_box.add_theme_constant_override("separation", 8)
	right.add_child(res_bonus_box)
	res_bonus_lbl = _label(res_bonus_box, "BONUS COINS - tap to stop!", 30, GOLD)
	res_meter = Meter.new()
	res_meter.custom_minimum_size = Vector2(520, 52)
	res_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	res_bonus_box.add_child(res_meter)
	res_bonus_btn = _button(res_bonus_box, "STOP!", 44, Color(0.9, 0.5, 0.15), Vector2(340, 80))
	res_bonus_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	res_bonus_btn.pressed.connect(_on_bonus_stop)
	res_double_btn = _button(res_bonus_box, "x2 COINS  (watch ad)", 28, Color(0.15, 0.55, 0.65), Vector2(340, 62))
	res_double_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	res_double_btn.pressed.connect(func():
		res_double_btn.disabled = true
		double_requested.emit())

	confetti = CPUParticles2D.new()
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 100
	confetti.lifetime = 2.6
	confetti.explosiveness = 0.85
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(640, 6)
	confetti.direction = Vector2(0, 1)
	confetti.spread = 25.0
	confetti.gravity = Vector2(0, 380)
	confetti.initial_velocity_min = 250.0
	confetti.initial_velocity_max = 650.0
	confetti.angular_velocity_min = -300.0
	confetti.angular_velocity_max = 300.0
	confetti.scale_amount_min = 6.0
	confetti.scale_amount_max = 13.0
	var cg := Gradient.new()
	cg.colors = PackedColorArray([Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.9, 0.4), Color(0.3, 0.6, 1.0), Color(0.9, 0.4, 1.0)])
	cg.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	confetti.color_initial_ramp = cg
	confetti.position = Vector2(640, -20)
	add_child(confetti)

	res_buttons = VBoxContainer.new()
	res_buttons.add_theme_constant_override("separation", 12)
	right.add_child(res_buttons)
	var again := _button(res_buttons, "PLAY AGAIN", 56, GREEN, Vector2(460, 108), "icon_replay", 72)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func(): again_pressed.emit())
	var hbtn := _button(res_buttons, "HOME", 36, Color(0.35, 0.4, 0.5), Vector2(240, 66), "icon_home", 44)
	hbtn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hbtn.pressed.connect(func(): home_pressed.emit())
	result.visible = false


func _on_bonus_stop() -> void:
	if not res_meter.running:
		return
	res_meter.running = false
	var m := res_meter.mult()
	res_bonus_btn.visible = false
	res_bonus_lbl.text = "BONUS x%d!   +%d coins" % [m, res_gain * (m - 1)]
	res_bonus_lbl.scale = Vector2(1.3, 1.3)
	res_bonus_lbl.pivot_offset = res_bonus_lbl.size * 0.5
	create_tween().tween_property(res_bonus_lbl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	bonus_claimed.emit(m)


func show_result(d: Dictionary) -> void:
	res_head.text = str(d["head"])
	res_head.add_theme_color_override("font_color", GOLD if d["won"] else Color(1, 0.6, 0.5))
	res_head.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(res_head, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var info := "Score %d" % int(d["score"])
	if d["new_best"]:
		info += "   NEW BEST!"
	info += "\n+%d coins    +%d XP" % [int(d["gain"]), int(d["xp"])]
	if d["level_up"]:
		info += "\nLEVEL UP!  +100 coins"
	res_info.text = info
	res_near.text = str(d["near"])
	res_xp.max_value = profile.xp_needed()
	res_xp.value = 0.0
	create_tween().tween_property(res_xp, "value", float(profile.xp), 0.8).set_delay(0.3)
	res_board.text = str(d["board"])
	res_gain = int(d["gain"])
	res_bonus_box.visible = res_gain > 0
	res_bonus_btn.visible = true
	res_double_btn.disabled = false
	res_double_btn.text = "x2 COINS  (watch ad)"
	res_double_btn.visible = res_gain > 0 and not profile.vip and mon != null and mon.rewarded_available()
	res_bonus_lbl.text = "BONUS COINS - tap to stop!"
	res_meter.t = 0.0
	res_meter.running = true
	home.visible = false
	hud.visible = false
	result.visible = true
	danger_rect.modulate.a = 0.0
	if d["won"]:
		confetti.restart()
	set_joystick(false, Vector2.ZERO, Vector2.ZERO)


# =====================================================================
# visibility
# =====================================================================
func show_home() -> void:
	danger_rect.modulate.a = 0.0
	home.visible = not intro_active   # the intro reveals it when it ends
	hud.visible = false
	result.visible = false
	pause_root.visible = false
	set_joystick(false, Vector2.ZERO, Vector2.ZERO)


func show_hud() -> void:
	home.visible = false
	hud.visible = true
	result.visible = false
	hint_lbl.text = ""
	combo_lbl.text = ""
	toast_lbl.text = ""
