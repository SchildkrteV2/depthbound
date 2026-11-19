class_name Tutorial
extends Node
## First-run hints on depth 1. Each hint stays until you do the thing it asks.
## Shown when "Tutorial hints" is on in Settings and the tutorial hasn't been finished.

var main: Node
var step := 0
var _t := 0.0
var _start_pos := Vector2.ZERO
var _start_attacks := 0


func _touch() -> bool:
	return main.touch.active


func _text() -> String:
	var touch := _touch()
	match step:
		0:
			return "Move with the left joystick" if touch else "Move with WASD or the arrow keys"
		1:
			return "Tap the attack button to strike - it aims for you" if touch else "Press SPACE to strike - it aims for you"
		2:
			return "Drag the attack button to aim, release to strike" if touch else "Hold the LEFT MOUSE button to aim, release to strike"
		3:
			return "Each attack uses a charge (blue bars, top left). They refill over time."
		4:
			return "Press the dodge button to dash through danger" if touch else "Press SHIFT (or right-click) to dodge through danger"
		5:
			return "Find the gold stairs (gold square on the minimap) to go deeper"
		6:
			return "Bosses wait every 10th floor. Kill one to DEVOUR its power!"
	return ""


func _process(delta: float) -> void:
	var p: Player = main.player
	if not is_instance_valid(p) or not main.playing:
		return
	_t += delta
	match step:
		0:
			if _start_pos == Vector2.ZERO:
				_start_pos = p.global_position
			if p.global_position.distance_to(_start_pos) > 40.0:
				_next()
		1:
			if p._attack_count > _start_attacks:
				_next()
		2:
			if p.last_attack_aimed:
				_next()
		3, 6:
			if _t > 6.0:
				_next()
		4:
			if p.dodge_t > 0.0:
				_next()
		5:
			if main.depth > 1:
				_next()
	main.hud.show_hint(_text())


func _next() -> void:
	step += 1
	_t = 0.0
	_start_attacks = main.player._attack_count
	main.sfx("click")
	if step > 6:
		Profile.data["tutorial_done"] = true
		Profile.save()
		main.hud.show_hint("")
		queue_free()
