class_name Hole
extends Node3D
## A hole (player or bot). Visual = black disc + glowing rim + name tag.

var r: float = 0.3
var target_r: float = 0.3
var color: Color = Color.WHITE
var rainbow: bool = false
var hname: String = ""
var is_player: bool = false
var is_boss: bool = false
var score: int = 0
var speed_mult: float = 1.0
var move_dir: Vector2 = Vector2.ZERO
var effects: Dictionary = {"speed": 0.0, "magnet": 0.0}
var invuln: float = 0.0
var combo: int = 0
var combo_t: float = 0.0
var pulse: float = 0.0
var max_r: float = 2.8
var aggr: float = 0.55

# bot brain
var skill: float = 1.0
var ai_timer: float = 0.0
var ai_target: Item = null
var ai_chase: Hole = null
var ai_flee: Vector2 = Vector2.ZERO
var ai_wander: Vector2 = Vector2.ZERO

var disc: MeshInstance3D
var rim: MeshInstance3D
var arrow: MeshInstance3D
var label: Label3D
var rim_mat: StandardMaterial3D


func setup(p_name: String, p_color: Color, p_player: bool, start_r: float) -> void:
	hname = p_name
	color = p_color
	is_player = p_player
	r = start_r
	target_r = start_r

	disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.01
	cyl.radial_segments = 40
	cyl.rings = 1
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment(){ float d = length(UV - vec2(0.5)) * 2.0; ALBEDO = mix(vec3(0.0, 0.0, 0.01), vec3(0.05, 0.07, 0.16), smoothstep(0.45, 1.0, d)); }"
	var dm := ShaderMaterial.new()
	dm.shader = sh
	disc.mesh = cyl
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)

	rim = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.86
	tor.outer_radius = 1.0
	tor.rings = 40
	tor.ring_segments = 8
	rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = color
	rim_mat.emission_enabled = true
	rim_mat.emission = color
	rim_mat.emission_energy_multiplier = 1.6
	rim.mesh = tor
	rim.material_override = rim_mat
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)

	label = Label3D.new()
	label.font = Fonts.ui()
	label.text = hname
	label.font_size = 56
	label.outline_size = 14
	label.modulate = color.lightened(0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	add_child(label)
	_apply_visuals()


func set_skin(c: Color, p_rainbow: bool) -> void:
	color = c
	rainbow = p_rainbow
	rim_mat.albedo_color = c
	rim_mat.emission = c
	label.modulate = c.lightened(0.35)


func add_mass(p: float, growth_mult: float) -> void:
	# every swallow gives a visible bump (floor), big things give much more
	target_r = minf(sqrt(target_r * target_r + maxf(p, 4.0) * 0.0026 * growth_mult), max_r)


func speed() -> float:
	var s: float = (2.8 + r * 0.85) * speed_mult
	if effects["speed"] > 0.0:
		s *= 1.6
	return s


func tick(delta: float, bound: float) -> void:
	for k in effects:
		effects[k] = maxf(0.0, effects[k] - delta)
	invuln = maxf(0.0, invuln - delta)
	pulse = maxf(0.0, pulse - delta * 4.0)
	combo_t -= delta
	if combo_t <= 0.0:
		combo = 0
	r = lerpf(r, target_r, 1.0 - exp(-8.0 * delta))
	var d := move_dir
	if d.length() > 1.0:
		d = d.normalized()
	position.x = clampf(position.x + d.x * speed() * delta, -bound, bound)
	position.z = clampf(position.z + d.y * speed() * delta, -bound, bound)
	if rainbow:
		var c := Color.from_hsv(fposmod(Time.get_ticks_msec() * 0.0004, 1.0), 0.8, 1.0)
		rim_mat.albedo_color = c
		rim_mat.emission = c
		label.modulate = c.lightened(0.3)
	_apply_visuals()


func _apply_visuals() -> void:
	position.y = 0.115 + r * 0.002 + (0.001 if is_player else 0.0)
	var pr := r * (1.0 + 0.14 * pulse)
	disc.scale = Vector3(pr, 1.0, pr)
	rim.scale = Vector3(pr, 1.0, pr)
	label.position = Vector3(0, 0.5 + r * 0.5, 0)
	var glow := 1.8
	if effects["speed"] > 0.0 or effects["magnet"] > 0.0:
		glow = 3.4
	if invuln > 0.0:
		glow = 1.0 + 1.6 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02))
	rim_mat.emission_energy_multiplier = glow + pulse * 2.0
