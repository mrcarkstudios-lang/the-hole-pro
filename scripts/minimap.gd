class_name Minimap
extends Control
## Corner mini-map: road grid, the safe zone, the player (white ring) and the other holes.

const SIZE := 168.0

var half: float = 22.0
var zone: float = 22.0
var roads: Array[float] = []
var dots: Array = []   # [x, z, r, color, is_player]


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_END


func set_data(p_dots: Array, p_zone: float) -> void:
	dots = p_dots
	zone = p_zone
	queue_redraw()


func _w2m(x: float, z: float) -> Vector2:
	return Vector2((x / half * 0.5 + 0.5) * SIZE, (z / half * 0.5 + 0.5) * SIZE)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	draw_rect(rect, Color(0.05, 0.12, 0.3, 0.62))
	for c in roads:
		var a := _w2m(c, 0.0).x
		var b := _w2m(0.0, c).y
		draw_line(Vector2(a, 0), Vector2(a, SIZE), Color(1, 1, 1, 0.16), 3.0)
		draw_line(Vector2(0, b), Vector2(SIZE, b), Color(1, 1, 1, 0.16), 3.0)
	if zone < half - 0.5:   # royale: the shrinking safe zone
		var z0 := _w2m(-zone, -zone)
		var z1 := _w2m(zone, zone)
		draw_rect(Rect2(z0, z1 - z0), Color(1, 0.3, 0.3, 0.9), false, 2.0)
	draw_rect(rect, Color(1.0, 0.85, 0.25, 0.9), false, 3.0)
	for d in dots:
		var p := _w2m(float(d[0]), float(d[1]))
		var rr := clampf(float(d[2]) / half * SIZE * 0.5, 3.5, 14.0)
		var col: Color = d[3]
		if d[4]:
			draw_circle(p, rr + 3.0, Color(1, 1, 1, 0.95))
			draw_circle(p, rr, Color(0.03, 0.04, 0.12, 1.0))
		else:
			draw_circle(p, rr + 1.5, Color(0.03, 0.04, 0.12, 0.9))
			draw_circle(p, rr, col)
