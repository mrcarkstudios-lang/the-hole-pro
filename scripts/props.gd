class_name Props
extends RefCounted
## Extra props built from primitives (our own assets, matching the low-poly style).
## Used next to the KayKit models: trees, barrels, crates, cones, bins, gold, fountain.


static func mat(c: Color, emit: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func _cyl(n: Node3D, top: float, bottom: float, h: float, m: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	n.add_child(mi)


static func _box(n: Node3D, size: Vector3, m: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	n.add_child(mi)


static func build(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"tree":
			_cyl(n, 0.03, 0.04, 0.2, mat(Color(0.45, 0.3, 0.18)), Vector3(0, 0.1, 0))
			_cyl(n, 0.0, 0.17, 0.34, mat(Color(0.2, 0.62, 0.25)), Vector3(0, 0.36, 0))
			_cyl(n, 0.0, 0.12, 0.28, mat(Color(0.28, 0.72, 0.3)), Vector3(0, 0.54, 0))
		"barrel":
			_cyl(n, 0.085, 0.09, 0.24, mat(Color(0.8, 0.25, 0.2)), Vector3(0, 0.12, 0))
			_cyl(n, 0.092, 0.092, 0.03, mat(Color(0.2, 0.2, 0.25)), Vector3(0, 0.12, 0))
		"crate":
			_box(n, Vector3(0.22, 0.22, 0.22), mat(Color(0.72, 0.5, 0.28)), Vector3(0, 0.11, 0))
			_box(n, Vector3(0.235, 0.04, 0.235), mat(Color(0.55, 0.37, 0.2)), Vector3(0, 0.11, 0))
		"cone":
			_cyl(n, 0.015, 0.075, 0.22, mat(Color(1.0, 0.5, 0.1)), Vector3(0, 0.11, 0))
			_box(n, Vector3(0.18, 0.02, 0.18), mat(Color(0.25, 0.25, 0.28)), Vector3(0, 0.01, 0))
		"bin":
			_cyl(n, 0.075, 0.065, 0.2, mat(Color(0.35, 0.55, 0.5)), Vector3(0, 0.1, 0))
			_cyl(n, 0.085, 0.085, 0.03, mat(Color(0.28, 0.45, 0.4)), Vector3(0, 0.215, 0))
		"gold":
			var g := mat(Color(1.0, 0.8, 0.15), 0.9, 0.7)
			_box(n, Vector3(0.3, 0.08, 0.14), g, Vector3(0, 0.04, 0))
			_box(n, Vector3(0.28, 0.08, 0.14), g, Vector3(0.01, 0.12, 0))
			_box(n, Vector3(0.2, 0.08, 0.12), g, Vector3(-0.02, 0.2, 0))
		"fountain":
			_cyl(n, 0.45, 0.5, 0.14, mat(Color(0.75, 0.78, 0.85)), Vector3(0, 0.07, 0))
			_cyl(n, 0.4, 0.4, 0.02, mat(Color(0.3, 0.65, 0.95), 0.4), Vector3(0, 0.14, 0))
			_cyl(n, 0.05, 0.07, 0.4, mat(Color(0.8, 0.82, 0.9)), Vector3(0, 0.3, 0))
			_cyl(n, 0.2, 0.1, 0.09, mat(Color(0.75, 0.78, 0.85)), Vector3(0, 0.5, 0))
		_:
			_box(n, Vector3(0.15, 0.15, 0.15), mat(Color.WHITE), Vector3(0, 0.075, 0))
	return n
