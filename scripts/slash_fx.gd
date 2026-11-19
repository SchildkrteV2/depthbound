class_name SlashFx
extends Node2D
## Short-lived attack visual: a sweeping slash, a thrust, or an expanding ring.

var shape := "arc"
var angle := 0.0
var reach := 40.0
var arc_deg := 110.0
var width := 12.0
var flip := 1.0
var color := Color(0.8, 0.85, 1.0)
var duration := 0.25
var _t := 0.0


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - k, 3.0) # ease-out
	var fade := 1.0 - k
	match shape:
		"arc":
			var half := deg_to_rad(arc_deg) * 0.5
			var start := angle - half * flip
			var sweep := deg_to_rad(arc_deg) * flip * grow
			var tail := deg_to_rad(arc_deg) * flip * maxf(grow - 0.55, 0.0)
			var pts := PackedVector2Array()
			var steps := 14
			for i in steps + 1:
				var a := start + tail + (sweep - tail) * i / steps
				pts.append(Vector2.RIGHT.rotated(a) * reach)
			for i in range(steps, -1, -1):
				var a := start + tail + (sweep - tail) * i / steps
				pts.append(Vector2.RIGHT.rotated(a) * reach * 0.55)
			if pts.size() >= 3:
				draw_colored_polygon(pts, Color(color, 0.55 * fade))
			# Bright leading edge.
			var edge := Vector2.RIGHT.rotated(start + sweep)
			draw_line(edge * reach * 0.5, edge * reach, Color(1, 1, 1, fade), 2.0)
		"thrust":
			var dir := Vector2.RIGHT.rotated(angle)
			var side := Vector2(-dir.y, dir.x) * width * 0.5 * (1.0 - k * 0.6)
			var tip := dir * reach * grow
			draw_colored_polygon(PackedVector2Array([side, tip, -side]), Color(color, 0.6 * fade))
			draw_line(Vector2.ZERO, tip, Color(1, 1, 1, fade), 1.5)
		"slam", "circle":
			draw_circle(Vector2.ZERO, reach * grow, Color(color, 0.18 * fade))
			draw_arc(Vector2.ZERO, reach * grow, 0.0, TAU, 32, Color(color, 0.8 * fade), 2.5)
			if shape == "slam":
				for i in 8:
					var d := Vector2.RIGHT.rotated(TAU * i / 8.0 + 0.3)
					draw_line(d * reach * 0.2, d * reach * 0.2 + d * reach * 0.5 * grow, Color(1, 0.9, 0.7, fade), 1.5)
			else:
				var a := angle + TAU * grow * flip
				var d := Vector2.RIGHT.rotated(a)
				draw_line(d * reach * 0.4, d * reach, Color(1, 1, 1, fade), 2.0)
