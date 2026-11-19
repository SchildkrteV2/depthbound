class_name Elevator
extends Area2D
## Loot Lift: appears on every 5th floor. Step on it to send the monster parts in your bag up
## to the Workshop (only the loot - you and your gold stay). On boss floors it stays locked until the boss dies.

var main: Node
var locked := false
var _armed := true
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 10)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, 2)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_child(Torch.make_light(80.0, Color(0.5, 1.0, 0.6), 0.6))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player and _armed and not locked:
		_armed = false
		main.on_elevator()


func _on_body_exited(body: Node) -> void:
	if body is Player:
		_armed = true


func unlock() -> void:
	locked = false


func _draw() -> void:
	Sprites.draw_at(self, Sprites.item("elevator"), Vector2(0, 9))
	# Signal lamps: blinking green when ready, red while locked.
	var on := int(_t * 2.0) % 2 == 0
	var lamp := Color(1.0, 0.25, 0.2) if locked else Color(0.4, 1.0, 0.5)
	for x in [-7.0, 6.0]:
		draw_rect(Rect2(x, -6, 2, 2), lamp if on else lamp.darkened(0.6))
	if not locked:
		draw_circle(Vector2(0, 4), 9.0 + sin(_t * 3.0), Color(0.4, 1.0, 0.5, 0.08))
	draw_string(ThemeDB.fallback_font, Vector2(-30, -10), "LOCKED" if locked else "SEND LOOT", HORIZONTAL_ALIGNMENT_CENTER, 60, 7, lamp)
