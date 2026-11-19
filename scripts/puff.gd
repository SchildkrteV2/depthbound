class_name Puff
extends Node2D
## Short burst effect for hits and deaths.

const DURATION := 0.35

var color := Color.WHITE
var size := 8.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	draw_circle(Vector2.ZERO, size * (0.4 + k), Color(color, 0.5 * (1.0 - k)))
	for i in 6:
		var dir := Vector2.RIGHT.rotated(TAU * i / 6.0 + size)
		draw_circle(dir * size * (0.5 + k * 1.2), 1.5 * (1.0 - k) + 0.3, Color(color, 1.0 - k))
