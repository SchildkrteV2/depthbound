class_name Puddle
extends Node2D
## Poison left behind by toxic elites. Hurts the player while standing in it.

const DURATION := 3.5
const RADIUS := 12.0

var _t := 0.0


func _ready() -> void:
	z_index = -1


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	var main := get_tree().current_scene
	var p: Player = main.player if main else null
	if p and not p.dead and _t > 0.3 and p.global_position.distance_to(global_position) < RADIUS + Player.RADIUS * 0.5:
		p.take_damage(1)
	queue_redraw()


func _draw() -> void:
	var fade := clampf((DURATION - _t) / 0.8, 0.0, 1.0) * clampf(_t / 0.3, 0.0, 1.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.45, 0.85, 0.15, 0.35 * fade))
	draw_circle(Vector2(3, -2), RADIUS * 0.4, Color(0.6, 1.0, 0.3, 0.3 * fade))
