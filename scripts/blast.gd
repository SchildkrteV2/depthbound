class_name Blast
extends Node2D
## A telegraphed explosion: shows a warning circle for `delay` seconds, then hits
## everything inside `radius`. Used by the mage staff (hurts enemies) and by
## enemies like the bomber or boss slams (hurts the player).

var radius := 30.0
var delay := 0.35
var damage := 10.0
var from_player := true
var source: Node = null # Player for player blasts
var color := Color(1.0, 0.55, 0.2)
var stun := 0.0 # player blasts can stun what they hit
var _t := 0.0
var _done := false


func _ready() -> void:
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t >= delay:
		_done = true
		_detonate()
	if _t >= delay + 0.25:
		queue_free()
	queue_redraw()


func _detonate() -> void:
	var main := get_tree().current_scene
	if from_player:
		for n in get_tree().get_nodes_in_group("enemies"):
			var e := n as Enemy
			if e == null or e.dying:
				continue
			var to := e.global_position - global_position
			if to.length() - e.radius <= radius and is_instance_valid(source):
				source.deal_damage(e, damage, to.normalized() if to.length() > 0.1 else Vector2.RIGHT)
				if stun > 0.0 and is_instance_valid(e):
					e.stun = maxf(e.stun, stun)
	else:
		var p: Player = main.player if main else null
		if p and not p.dead and p.global_position.distance_to(global_position) <= radius + Player.RADIUS:
			p.take_damage(int(damage))
	if main:
		main.shake(2.5)
		main.sfx("boom")


func _draw() -> void:
	if not _done:
		var k := clampf(_t / delay, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.08 + 0.12 * k))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.6), 1.5)
		draw_circle(Vector2.ZERO, radius * k, Color(color, 0.2))
	else:
		var k := clampf((_t - delay) / 0.25, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius * (0.8 + 0.4 * k), Color(color, 0.6 * (1.0 - k)))
		draw_circle(Vector2.ZERO, radius * 0.6 * (1.0 - k), Color(1, 0.95, 0.7, 1.0 - k))
		draw_arc(Vector2.ZERO, radius * (1.0 + 0.3 * k), 0.0, TAU, 32, Color(color, 1.0 - k), 2.0)
