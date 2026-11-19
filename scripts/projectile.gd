class_name Projectile
extends Area2D
## A projectile fired by the player (arrows) or by enemies. Stops at walls.

var velocity := Vector2.ZERO
var damage := 1.0
var from_player := true
var life := 1.0
var pierce := 0
var source: Node = null # the Player, for player-owned shots (applies crits etc.)
var style := "orb" # "orb", "arrow", "knife", "bolt", "spirit"
var homing := false # turns toward the nearest enemy (Spirit Swarm)
var _hit := {}
var _done := false
## Where the shot was fired from. On its first step the wall check runs from here, so a shot
## fired while hugging a wall cannot start on the far side of it.
var origin := Vector2.INF


func setup(vel: Vector2, dmg: float, player_owned: bool, lifetime: float, pierce_count: int) -> void:
	velocity = vel
	damage = dmg
	from_player = player_owned
	life = lifetime
	pierce = pierce_count


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | (4 if from_player else 2)
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = 3.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if _done:
		return
	if homing:
		var best: Node2D = null
		var bd := 160.0
		for e in get_tree().get_nodes_in_group("enemies"):
			var d: float = global_position.distance_to(e.global_position)
			if d < bd and not _hit.has(e):
				bd = d
				best = e
		if best:
			var want := (best.global_position - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, minf(1.0, delta * 6.0))
			rotation = velocity.angle()
	# Sweep the path to the next position against walls (a fast shot could otherwise step
	# straight over a thin wall between two physics frames).
	var from := global_position if origin == Vector2.INF else origin
	origin = Vector2.INF
	var to := global_position + velocity * delta
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var wall := get_world_2d().direct_space_state.intersect_ray(q)
	if not wall.is_empty() and wall["collider"] is StaticBody2D: # monsters share layer 1 - only walls count
		global_position = wall["position"] - velocity.normalized() * 1.0
		_finish()
		return
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if body is StaticBody2D:
		_finish()
		return
	if not body.has_method("take_damage"):
		return
	if from_player:
		if _hit.has(body):
			return
		_hit[body] = true
		if is_instance_valid(source):
			source.deal_damage(body, damage, velocity.normalized())
		else:
			body.take_damage(damage, velocity.normalized())
		if pierce > 0:
			pierce -= 1
		else:
			_finish()
	else:
		body.take_damage(int(damage), velocity.normalized())
		_finish()


func _finish() -> void:
	_done = true
	var main := get_tree().current_scene
	if main and main.has_method("spawn_puff"):
		main.spawn_puff(global_position, _color(), 5.0)
	queue_free()


var color_override := Color(0, 0, 0, 0) # enemies can set their own projectile colour


func _color() -> Color:
	if color_override.a > 0.0:
		return color_override
	if not from_player:
		return Color(1.0, 0.55, 0.25)
	if style == "spirit":
		return Color(0.6, 1.0, 0.85)
	return Color(0.85, 0.5, 1.0) if style == "bolt" else Color(0.85, 0.9, 1.0)


func _draw() -> void:
	# Drawn in local space; the node is rotated to face its velocity.
	var c := _color()
	if style == "knife":
		Sprites.draw_centered(self, Sprites.item("knife"), Vector2(-1, 0))
	elif style == "arrow":
		Sprites.draw_centered(self, Sprites.item("arrow"), Vector2(-2.5, 0))
	else:
		draw_circle(Vector2.ZERO, 4.5, Color(c, 0.25))
		Sprites.draw_centered(self, Sprites.orb(c), Vector2.ZERO)
