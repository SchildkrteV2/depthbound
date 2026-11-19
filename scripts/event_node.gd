class_name EventNode
extends Area2D
## A rare floor event the player walks into:
##   trader   - shop: spend gold on healing, upgrades and weapons
##   shrine   - offer health for a blessing (upgrade choice)
##   chest    - gold, maybe hearts or a free upgrade
##   fountain - full heal, once
##   slots    - the Cursed Idol: a slot machine (gold for a pull; rising price each pull)
## Walking in triggers it. Re-usable events (trader) re-arm after you step away.

const INFO := {
	"trader": {"name": "Wandering Trader", "banner": "You hear a merchant's bell somewhere on this floor..."},
	"shrine": {"name": "Blood Shrine", "banner": "An old shrine hums somewhere on this floor..."},
	"chest": {"name": "Treasure Chest", "banner": "You smell gold on this floor..."},
	"fountain": {"name": "Healing Fountain", "banner": "You hear running water somewhere on this floor..."},
	"slots": {"name": "Cursed Idol", "banner": "Coins rattle inside something on this floor..."},
}

var main: Node
var kind := "trader"
var used := false
var _armed := true
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = 11.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("events")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player and _armed and not used:
		_armed = false
		main.on_event(self)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		_armed = true


func _draw() -> void:
	draw_set_transform(Vector2(0, 7), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	match kind:
		"trader":
			# Hooded merchant behind a counter of potions, with a lantern.
			var bob := 0.0 if fmod(_t, 2.0) < 1.6 else -1.0
			Sprites.draw_at(self, Sprites.item("merchant"), Vector2(0, 2 + bob))
			Sprites.draw_at(self, Sprites.item("counter"), Vector2(0, 9))
			draw_circle(Vector2(13, -8), 3.0 + pulse, Color(1.0, 0.85, 0.4, 0.3))
			Sprites.draw_at(self, Sprites.item("lantern"), Vector2(13, -5))
		"shrine":
			Sprites.draw_at(self, Sprites.item("shrine_used" if used else "shrine"), Vector2(0, 8))
			if not used:
				draw_circle(Vector2(0, -8), 5.0 + pulse * 2.0, Color(0.9, 0.2, 0.3, 0.25))
		"chest":
			Sprites.draw_at(self, Sprites.item("chest", 1 if used else 0), Vector2(0, 7))
			if not used:
				draw_circle(Vector2(0, -1), 12.0, Color(1.0, 0.85, 0.3, 0.06 + 0.08 * pulse))
		"fountain":
			var mod := Color(0.45, 0.45, 0.55) if used else Color.WHITE
			Sprites.draw_at(self, Sprites.item("fountain", int(_t * 3.0)), Vector2(0, 8), false, mod)
			if not used:
				for i in 3:
					var y := -fmod(_t * 12.0 + i * 5.0, 14.0)
					draw_rect(Rect2(Vector2(round(sin(i * 2.0) * 2.0), round(y) - 1.0), Vector2(1, 2)), Color(0.7, 0.9, 1.0, 1.0 + y / 14.0))
		"slots":
			# The Cursed Idol: eyes glint, a coin glow pulses over the reels.
			Sprites.draw_at(self, Sprites.item("idol", 1 if fmod(_t, 1.6) < 0.2 else 0), Vector2(0, 8))
			draw_circle(Vector2(0, -2), 10.0 + pulse * 2.0, Color(1.0, 0.8, 0.3, 0.06 + 0.06 * pulse))
