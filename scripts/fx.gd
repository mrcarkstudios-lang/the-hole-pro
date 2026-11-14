class_name Fx
extends Node3D
## Juice: pooled particle bursts, expanding rings, floating text.

var pool: Array[CPUParticles3D] = []
var idx: int = 0


func _ready() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.07, 0.07)
	mesh.material = m
	for i in 14:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 16
		p.lifetime = 0.7
		p.explosiveness = 1.0
		p.mesh = mesh
		p.direction = Vector3(0, 1, 0)
		p.spread = 75.0
		p.gravity = Vector3(0, -9.0, 0)
		p.initial_velocity_min = 1.2
		p.initial_velocity_max = 3.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.5
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		pool.append(p)


func burst(pos: Vector3, col: Color, power: float = 1.0) -> void:
	var p := pool[idx]
	idx = (idx + 1) % pool.size()
	p.position = pos
	p.color = col
	p.initial_velocity_min = 1.0 * power
	p.initial_velocity_max = 3.2 * power
	p.scale_amount_max = 1.2 + 0.5 * power
	p.restart()


func ring(pos: Vector3, radius: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col.r, col.g, col.b, 0.9)
	mi.mesh = t
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3(radius * 0.6, 1, radius * 0.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius * 2.2, 1, radius * 2.2), 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)


func popup(pos: Vector3, text: String, col: Color, size: float = 1.0) -> void:
	var l := Label3D.new()
	l.font = Fonts.ui()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.0055 * size
	l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = col
	l.position = pos + Vector3(0, 0.6, 0)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.3, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
