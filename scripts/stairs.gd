class_name Stairs
extends Area2D
## The way down. Locked on boss floors until the boss dies.
## A "plunge" is the cursed second staircase: skips a floor, better reward, adds a curse.

var main: Node
var locked := false
var plunge := false
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 12)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	add_child(Torch.make_light(70.0, Color(0.9, 0.3, 1.0) if plunge else Color(1.0, 0.85, 0.4), 0.5))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player and not locked:
		main.on_stairs_reached(plunge)


func unlock() -> void:
	locked = false
	for b in get_overlapping_bodies():
		if b is Player:
			main.on_stairs_reached.call_deferred(plunge)


func _draw() -> void:
	var glow := Color(0.85, 0.3, 1.0) if plunge else Color(1.0, 0.85, 0.4)
	Sprites.draw_centered(self, Sprites.stairs(plunge), Vector2.ZERO)
	if locked:
		# Iron bars until the boss is dead.
		for i in 4:
			var x := -6.0 + i * 4.0
			draw_rect(Rect2(x, -9, 2, 18), Color(0.25, 0.08, 0.1))
			draw_rect(Rect2(x, -9, 1, 18), Color(0.65, 0.2, 0.25))
		draw_rect(Rect2(-8, -2, 16, 2), Color(0.5, 0.15, 0.2))
		return
	var r := 12.0 + sin(_t * 3.0) * 1.5
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(glow, 0.55), 1.5)
	var bob := sin(_t * 4.0) * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -17 + bob), Vector2(3, -17 + bob), Vector2(0, -13 + bob)]), glow)
	if plunge:
		# Swirling cursed motes.
		for i in 5:
			var p := Vector2.RIGHT.rotated(_t * 2.5 + TAU * i / 5.0) * (9.0 + 3.0 * sin(_t * 3.0 + i))
			draw_circle(p, 1.3, Color(0.9, 0.3, 1.0, 0.9))
		draw_string(ThemeDB.fallback_font, Vector2(-30, -21), "PLUNGE", HORIZONTAL_ALIGNMENT_CENTER, 60, 7, glow)
