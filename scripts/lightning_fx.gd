class_name LightningFx
extends Node2D
## Jagged lightning through a list of world points. Positioned at the world origin.

const DURATION := 0.22

var points: Array[Vector2] = []
var color := Color(0.6, 0.85, 1.0)
var _t := 0.0
var _jag: Array[Vector2] = []


func _ready() -> void:
	z_index = 6
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var n := maxi(2, int(a.distance_to(b) / 10.0))
		var side := (b - a).normalized().orthogonal()
		for k in n:
			var p := a.lerp(b, float(k) / n)
			if k > 0:
				p += side * randf_range(-4.0, 4.0)
			_jag.append(p)
	if points.size() > 0:
		_jag.append(points[points.size() - 1])


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _jag.size() < 2:
		return
	var fade := 1.0 - _t / DURATION
	draw_polyline(PackedVector2Array(_jag), Color(color, 0.35 * fade), 5.0)
	draw_polyline(PackedVector2Array(_jag), Color(1, 1, 1, fade), 1.5)
	for p in points:
		draw_circle(p, 5.0 * fade, Color(color, 0.5 * fade))
