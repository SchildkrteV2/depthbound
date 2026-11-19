class_name Dust
extends Node2D
## A little pixel dust puff kicked up by feet (walking, dodging, falling over).

const FRAME_TIME := 0.07

var flip := false
var drift := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	z_index = -1
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF # moves in _process


func _process(delta: float) -> void:
	_t += delta
	position += drift * delta
	if _t >= FRAME_TIME * Sprites.item_frames("dust"):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	Sprites.draw_at(self, Sprites.item("dust", int(_t / FRAME_TIME)), Vector2.ZERO, flip)
