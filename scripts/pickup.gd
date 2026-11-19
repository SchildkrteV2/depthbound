class_name Pickup
extends Area2D
## Gold, heart, monster part or gear dropped by enemies. Gold, hearts and parts get pulled
## toward the player when close; gear stays put (you walk over it to look at it).

const MAGNET_RANGE := 44.0

var main: Node
var kind := "gold" # "gold", "heart", "part" or "gear"
var part := "" # monster part id (see Materials)
var item := {} # gear piece (see Gear)
var value := 1
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_t = randf() * 5.0


func _physics_process(delta: float) -> void:
	_t += delta
	var p: Player = main.player
	if is_instance_valid(p) and not p.dead and kind != "gear":
		if kind == "heart" and p.hp >= p.max_hp:
			pass # don't chase the player if we can't be used
		elif global_position.distance_to(p.global_position) < MAGNET_RANGE * p.magnet:
			global_position = global_position.move_toward(p.global_position, 170.0 * delta)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player and main.collect(self):
		queue_free()


func _draw() -> void:
	var bob := Vector2(0, round(sin(_t * 4.0) * 1.5))
	draw_set_transform(Vector2(0, 5), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 4.0 if kind != "gear" else 7.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if kind == "gear":
		# Loot: a soft light beam (gold for rare pieces) and the item bobbing above it.
		var col := Color(1.0, 0.45, 0.1) if item.get("legendary", false) else (Color(1.0, 0.8, 0.3) if item.get("rare", false) else Color(0.5, 0.8, 1.0))
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_rect(Rect2(-3, -26, 6, 30), Color(col, 0.08 + 0.06 * pulse))
		draw_rect(Rect2(-1, -26, 2, 30), Color(col, 0.12 + 0.08 * pulse))
		draw_circle(Vector2(0, -6) + bob, 9.0, Color(col, 0.12 + 0.08 * pulse))
		var tex := Sprites.gear_icon(item)
		var ang := -PI / 4.0 if item.get("slot") == "weapon" else 0.0
		Sprites.draw_centered(self, tex, Vector2(0, -6) + bob, Color.WHITE, ang)
		if fmod(_t * 1.2, 1.0) < 0.12:
			draw_rect(Rect2(Vector2(4, -12) + bob, Vector2(1, 1)), Color(1, 1, 1))
	elif kind == "part":
		# Monster part, with a little glint so it stands out from gold.
		Sprites.draw_at(self, Sprites.item("part_" + part), Vector2(0, 4) + bob)
		if fmod(_t * 1.5, 1.0) < 0.15:
			draw_rect(Rect2(Vector2(2, -5) + bob, Vector2(1, 1)), Color(1, 1, 1))
	elif kind == "heart":
		# Beats twice a second.
		var beat := 1 if fmod(_t * 2.0, 1.0) < 0.18 else 0
		Sprites.draw_at(self, Sprites.item("heart", beat), Vector2(0, 4) + bob)
	else:
		# Spinning coin.
		Sprites.draw_at(self, Sprites.item("coin", int(_t * 8.0)), Vector2(0, 4) + bob)
