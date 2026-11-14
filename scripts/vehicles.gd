class_name Vehicles
extends RefCounted
## Procedural low-poly vehicles and pedestrians (our own models, matching the KayKit style).
## Every model faces +Z, sits on y=0 and shares cached meshes/materials.

const KINDS: Array[String] = ["person", "bicycle", "motorbike", "truck", "bus", "schoolbus",
	"firetruck", "tanker", "garbage", "signal_0", "signal_1"]
const SKINS: Array[Color] = [Color(0.96, 0.8, 0.64), Color(0.8, 0.58, 0.42), Color(0.56, 0.38, 0.27), Color(1.0, 0.87, 0.74)]
const PANTS: Array[Color] = [Color(0.2, 0.25, 0.42), Color(0.25, 0.25, 0.3), Color(0.38, 0.32, 0.24), Color(0.18, 0.3, 0.28)]
const GLASS := Color(0.62, 0.82, 0.95)
const DARK := Color(0.12, 0.12, 0.15)

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


static var sig_mats: Array = []   # [axis][0 red, 1 yellow, 2 green]
const SIG_COLS: Array[Color] = [Color(1.0, 0.15, 0.1), Color(1.0, 0.8, 0.1), Color(0.2, 1.0, 0.3)]


static func _sig_init() -> void:
	if not sig_mats.is_empty():
		return
	for a in 2:
		var row: Array = []
		for i in 3:
			var m := StandardMaterial3D.new()
			m.albedo_color = SIG_COLS[i] * 0.25
			m.emission_enabled = true
			m.emission = SIG_COLS[i]
			m.emission_energy_multiplier = 0.0
			row.append(m)
		sig_mats.append(row)


## state: 0 red, 1 yellow, 2 green
static func set_signal(axis: int, state: int) -> void:
	_sig_init()
	for i in 3:
		var m: StandardMaterial3D = sig_mats[axis][i]
		var on := i == state
		m.emission_energy_multiplier = 3.5 if on else 0.0
		m.albedo_color = SIG_COLS[i] if on else SIG_COLS[i] * 0.25


static func _signal(n: Node3D, axis: int) -> void:
	_sig_init()
	_cyl(n, 0.022, 0.028, 0.95, Color(0.22, 0.24, 0.3), Vector3(0, 0.475, 0))
	_box(n, Vector3(0.15, 0.42, 0.13), Color(0.1, 0.1, 0.13), Vector3(0, 1.0, 0))
	for i in 3:
		var y := 1.12 - 0.12 * float(i)
		for zs in [1.0, -1.0]:
			var key := "sb"
			if not _meshes.has(key):
				var sm := SphereMesh.new()
				sm.radius = 0.045
				sm.height = 0.09
				sm.radial_segments = 8
				sm.rings = 4
				_meshes[key] = sm
			_add(n, _meshes[key], sig_mats[axis][i], Vector3(0, y, 0.062 * zs))


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func mat(c: Color, emit: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func _add(n: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)


static func _box(n: Node3D, size: Vector3, c: Color, pos: Vector3, emit: float = 0.0) -> void:
	var key := "b%s" % size
	if not _meshes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_meshes[key] = b
	_add(n, _meshes[key], mat(c, emit), pos)


static func _cyl(n: Node3D, top: float, bottom: float, h: float, c: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var key := "c%s_%s_%s" % [top, bottom, h]
	if not _meshes.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = top
		cm.bottom_radius = bottom
		cm.height = h
		cm.radial_segments = 10
		cm.rings = 1
		_meshes[key] = cm
	_add(n, _meshes[key], mat(c), pos, rot)


static func _ball(n: Node3D, r: float, c: Color, pos: Vector3) -> void:
	var key := "s%s" % r
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 10
		sm.rings = 6
		_meshes[key] = sm
	_add(n, _meshes[key], mat(c), pos)


static func _wheel(n: Node3D, x: float, z: float, r: float, w: float) -> void:
	_cyl(n, r, r, w, DARK, Vector3(x, r, z), Vector3(0, 0, PI * 0.5))


static func _lights(n: Node3D, w: float, y: float, z: float) -> void:
	_box(n, Vector3(0.1, 0.07, 0.03), Color(1, 0.95, 0.7), Vector3(-w * 0.32, y, z), 1.5)
	_box(n, Vector3(0.1, 0.07, 0.03), Color(1, 0.95, 0.7), Vector3(w * 0.32, y, z), 1.5)


static func build(kind: String, col: Color = Color(0, 0, 0, 0)) -> Node3D:
	var n := Node3D.new()
	match kind:
		"person":
			_person(n, col, 0.0)
		"signal_0":
			_signal(n, 0)
		"signal_1":
			_signal(n, 1)
		"bicycle":
			_wheel(n, 0, 0.24, 0.1, 0.035)
			_wheel(n, 0, -0.24, 0.1, 0.035)
			_box(n, Vector3(0.035, 0.035, 0.46), Color(0.85, 0.2, 0.2) if col.a == 0.0 else col, Vector3(0, 0.2, 0))
			_box(n, Vector3(0.22, 0.03, 0.03), DARK, Vector3(0, 0.31, 0.2))
			_person(n, Color(0.2, 0.55, 0.95), 0.17)
		"motorbike":
			_wheel(n, 0, 0.3, 0.13, 0.07)
			_wheel(n, 0, -0.3, 0.13, 0.07)
			_box(n, Vector3(0.12, 0.16, 0.5), Color(0.9, 0.55, 0.1) if col.a == 0.0 else col, Vector3(0, 0.27, 0))
			_box(n, Vector3(0.26, 0.04, 0.04), DARK, Vector3(0, 0.38, 0.22))
			_lights(n, 0.2, 0.33, 0.38)
			_person(n, Color(0.15, 0.15, 0.2), 0.27)
		"truck":
			_truck(n, Color(0.95, 0.95, 0.97), col if col.a > 0.0 else Color(0.9, 0.3, 0.25), 2.0)
		"bus":
			_bus(n, col if col.a > 0.0 else Color(0.2, 0.55, 0.95), false)
		"schoolbus":
			_bus(n, Color(1.0, 0.78, 0.1), true)
		"firetruck":
			_truck(n, Color(0.9, 0.12, 0.12), Color(0.9, 0.12, 0.12), 2.3)
			_box(n, Vector3(0.36, 0.07, 1.3), Color(0.8, 0.82, 0.85), Vector3(0, 1.08, -0.35))
			_box(n, Vector3(0.82, 0.06, 1.2), Color(1, 1, 1), Vector3(0, 0.6, -0.35))
			_box(n, Vector3(0.4, 0.08, 0.1), Color(0.3, 0.5, 1.0), Vector3(0, 0.8, 0.75), 2.0)
		"tanker":
			_truck(n, Color(0.95, 0.95, 0.97), Color(0.2, 0.45, 0.9), 2.3, false)
			_cyl(n, 0.4, 0.4, 1.45, Color(0.82, 0.86, 0.9), Vector3(0, 0.62, -0.35), Vector3(PI * 0.5, 0, 0))
		"garbage":
			_truck(n, Color(0.2, 0.62, 0.3), Color(0.2, 0.62, 0.3), 2.2)
			_box(n, Vector3(0.82, 0.3, 0.16), DARK, Vector3(0, 0.42, -1.0))
		_:
			_box(n, Vector3(0.2, 0.2, 0.2), Color.WHITE, Vector3(0, 0.1, 0))
	return n


static func _person(n: Node3D, shirt: Color, lift: float) -> void:
	var c := shirt
	if c.a == 0.0:
		c = Color.from_hsv(randf(), 0.65, 0.95)
	var skin: Color = SKINS.pick_random()
	var pant: Color = PANTS.pick_random()
	_box(n, Vector3(0.045, 0.14, 0.05), pant, Vector3(-0.026, 0.07 + lift, 0))
	_box(n, Vector3(0.045, 0.14, 0.05), pant, Vector3(0.026, 0.07 + lift, 0))
	_cyl(n, 0.045, 0.055, 0.17, c, Vector3(0, 0.22 + lift, 0))
	_box(n, Vector3(0.03, 0.12, 0.035), c, Vector3(-0.07, 0.22 + lift, 0))
	_box(n, Vector3(0.03, 0.12, 0.035), c, Vector3(0.07, 0.22 + lift, 0))
	_ball(n, 0.05, skin, Vector3(0, 0.37 + lift, 0))


static func _truck(n: Node3D, cab: Color, cargo: Color, length: float, box_cargo: bool = true) -> void:
	var zf := length * 0.5
	_box(n, Vector3(0.7, 0.1, length - 0.05), DARK, Vector3(0, 0.2, 0))
	_box(n, Vector3(0.8, 0.56, 0.58), cab, Vector3(0, 0.5, zf - 0.32))
	_box(n, Vector3(0.72, 0.22, 0.03), GLASS, Vector3(0, 0.62, zf - 0.02))
	_lights(n, 0.8, 0.3, zf)
	if box_cargo:
		_box(n, Vector3(0.82, 0.8, length - 0.85), cargo, Vector3(0, 0.64, -0.33))
	for z in [zf - 0.3, -zf + 0.45, -zf + 0.85]:
		_wheel(n, -0.39, z, 0.17, 0.13)
		_wheel(n, 0.39, z, 0.17, 0.13)


static func _bus(n: Node3D, body: Color, school: bool) -> void:
	_box(n, Vector3(0.86, 0.74, 2.6), body, Vector3(0, 0.56, 0))
	_box(n, Vector3(0.88, 0.24, 2.3), GLASS, Vector3(0, 0.74, -0.05))
	_box(n, Vector3(0.78, 0.3, 0.03), GLASS, Vector3(0, 0.72, 1.31))
	_box(n, Vector3(0.88, 0.05, 2.6), DARK if school else Color(1, 1, 1), Vector3(0, 0.5, 0))
	_box(n, Vector3(0.7, 0.05, 2.4), body.lightened(0.15), Vector3(0, 0.95, 0))
	_lights(n, 0.86, 0.34, 1.3)
	for z in [0.85, -0.85]:
		_wheel(n, -0.4, z, 0.17, 0.12)
		_wheel(n, 0.4, z, 0.17, 0.12)
