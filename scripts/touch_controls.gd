class_name TouchControls
extends Control
## Mobile controls (Noctis-style):
## - Move side: floating joystick, appears where you put your thumb.
## - Attack side: ATTACK stick. Tap = auto-aim strike. Drag = aim, release = strike.
##   Drag out and back into the centre to cancel.
## - DODGE button and up to 4 ABILITY buttons (devoured boss powers) around it.
## Settings: button size, and swapping sides (move right / attack left).
## Shown automatically on mobile, or as soon as a touch is detected.

const STICK_RADIUS := 44.0
const ATTACK_RADIUS := 40.0
const DODGE_RADIUS := 26.0
const ABILITY_RADIUS := 19.0
const ABILITY_ANGLES := [200.0, 236.0, 272.0, 308.0] # degrees around the attack button
const MOVE_DEADZONE := 0.14
const AIM_DEADZONE := 0.28

var main: Node
var active := false

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO

var _atk_index := -1
var _atk_origin := Vector2.ZERO
var _atk_pos := Vector2.ZERO
var _atk_dragged := false

var _dodge_index := -1
var _ability_index := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	active = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	get_viewport().size_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_stick_index = -1
		_atk_index = -1
		_dodge_index = -1
		_ability_index = -1
		_push()


func _s() -> float:
	return float(GameSettings.values["button_scale"])


func _swapped() -> bool:
	return GameSettings.values["swap_sides"]


## Mirrors an x offset when the sides are swapped.
func _mx(x: float) -> float:
	return -x if _swapped() else x


func _attack_center() -> Vector2:
	var vp := get_viewport_rect().size
	var s := _s()
	return Vector2(78 * s if _swapped() else vp.x - 78 * s, vp.y - 78 * s)


func _dodge_center() -> Vector2:
	return _attack_center() + Vector2(_mx(-84), 22) * _s()


func _ability_center(i: int) -> Vector2:
	var d := Vector2.RIGHT.rotated(deg_to_rad(ABILITY_ANGLES[i])) * 82.0 * _s()
	return _attack_center() + Vector2(_mx(d.x), d.y)


func _on_move_side(pos: Vector2) -> bool:
	var half := get_viewport_rect().size.x * 0.5
	return pos.x >= half if _swapped() else pos.x < half


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		active = true
		var vp := get_viewport_rect().size
		var pos: Vector2 = event.position
		var s := _s()
		if event.pressed:
			var p: Player = main.player if main and is_instance_valid(main.player) else null
			var hit_ability := -1
			if p:
				for i in p.actives.size():
					if pos.distance_to(_ability_center(i)) < (ABILITY_RADIUS + 6.0) * s:
						hit_ability = i
			if hit_ability >= 0 and _ability_index == -1:
				_ability_index = event.index
				p.use_ability(hit_ability)
			elif pos.distance_to(_dodge_center()) < (DODGE_RADIUS + 8.0) * s and _dodge_index == -1:
				_dodge_index = event.index
				_player_call("request_dodge")
			elif _on_move_side(pos):
				if _stick_index == -1:
					_stick_index = event.index
					_stick_origin = pos
					_stick_pos = pos
			elif pos.y > vp.y * 0.18 and _atk_index == -1:
				_atk_index = event.index
				_atk_origin = pos
				_atk_pos = pos
				_atk_dragged = false
		else:
			if event.index == _stick_index:
				_stick_index = -1
			if event.index == _dodge_index:
				_dodge_index = -1
			if event.index == _ability_index:
				_ability_index = -1
			if event.index == _atk_index:
				_release_attack(true)
		_push()
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_index:
			_stick_pos = event.position
			var off := _stick_pos - _stick_origin
			if off.length() > STICK_RADIUS * _s():
				_stick_origin = _stick_pos - off.normalized() * STICK_RADIUS * _s()
		elif event.index == _atk_index:
			_atk_pos = event.position
			if _aim_vector().length() >= AIM_DEADZONE:
				_atk_dragged = true
		_push()
		queue_redraw()
	elif event is InputEventKey and event.pressed and active and not OS.has_feature("mobile"):
		active = false
		queue_redraw()


func _aim_vector() -> Vector2:
	return (_atk_pos - _atk_origin) / (ATTACK_RADIUS * _s())


func _release_attack(fire: bool) -> void:
	var v := _aim_vector()
	if fire:
		if v.length() >= AIM_DEADZONE:
			_player_call("queue_attack", [false, v.normalized(), v.length()])
		elif not _atk_dragged:
			_player_call("queue_attack", [true])
	_atk_index = -1


func _player_call(method: String, args: Array = []) -> void:
	if main and is_instance_valid(main.player):
		main.player.callv(method, args)


func _push() -> void:
	if main == null or not is_instance_valid(main.player):
		return
	var p: Player = main.player
	if _stick_index == -1:
		p.touch_move = Vector2.ZERO
	else:
		var mv := ((_stick_pos - _stick_origin) / (STICK_RADIUS * _s())).limit_length(1.0)
		p.touch_move = mv if mv.length() >= MOVE_DEADZONE else Vector2.ZERO
	var v := _aim_vector()
	p.touch_aiming = _atk_index != -1 and v.length() >= AIM_DEADZONE
	if p.touch_aiming:
		p.touch_aim = v.limit_length(1.0)


func _draw() -> void:
	if not active:
		return
	var vp := get_viewport_rect().size
	var s := _s()
	var p: Player = main.player if main and is_instance_valid(main.player) else null

	# Move stick.
	var using_stick := _stick_index != -1
	var idle := Vector2(vp.x - 84 * s if _swapped() else 84 * s, vp.y - 84 * s)
	var base := _stick_origin if using_stick else idle
	var knob := _stick_pos if using_stick else base
	draw_circle(base, STICK_RADIUS * s, Color(1, 1, 1, 0.08))
	draw_arc(base, STICK_RADIUS * s, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 2.0)
	draw_circle(knob, 18.0 * s, Color(1, 1, 1, 0.45 if using_stick else 0.22))

	# Attack stick.
	var held := _atk_index != -1
	var atk := _atk_origin if held else _attack_center()
	var aim_on := held and _aim_vector().length() >= AIM_DEADZONE
	var ar := ATTACK_RADIUS * s
	draw_circle(atk, ar, Color(1.0, 0.5, 0.3, 0.4 if held else 0.18))
	draw_arc(atk, ar, 0.0, TAU, 40, Color(1.0, 0.7, 0.5, 0.6), 2.0)
	if held:
		draw_circle(atk + _aim_vector().limit_length(0.9) * ar, 16.0 * s, Color(1, 1, 1, 0.55 if aim_on else 0.3))
	else:
		draw_line(atk + Vector2(-12, 12) * s, atk + Vector2(12, -12) * s, Color(1, 1, 1, 0.8), 3.0)
		draw_line(atk + Vector2(-14, 6) * s, atk + Vector2(-6, 14) * s, Color(1, 1, 1, 0.8), 3.0)
	if p:
		for i in p.max_charges:
			var ang := -PI * 0.5 - 0.5 + i * 0.32
			draw_circle(atk + Vector2.RIGHT.rotated(ang) * (ar + 9.0 * s), 4.0 * s, Color(0.8, 0.9, 1.0, 0.95) if i < p.charges else Color(0.3, 0.3, 0.4, 0.6))

	# Dodge button with cooldown ring.
	var dc := _dodge_center()
	var dr := DODGE_RADIUS * s
	var ready := p.dodge_ready() if p else 1.0
	draw_circle(dc, dr, Color(0.6, 0.45, 1.0, 0.45 if _dodge_index != -1 else 0.2))
	draw_arc(dc, dr, -PI / 2.0, -PI / 2.0 + TAU * ready, 32, Color(0.8, 0.7, 1.0, 0.8), 2.5)
	for i in 3:
		var x := (-8.0 + i * 6.0) * s
		var col := Color(1, 1, 1, 0.8 if ready >= 1.0 else 0.35)
		draw_line(dc + Vector2(x, -6 * s), dc + Vector2(x + 5 * s, 0), col, 2.0)
		draw_line(dc + Vector2(x + 5 * s, 0), dc + Vector2(x, 6 * s), col, 2.0)

	# Ability buttons (only for slots you have).
	if p:
		for i in p.actives.size():
			var c := _ability_center(i)
			var r := ABILITY_RADIUS * s
			var cd: float = p.ability_cd[i]
			var k := 1.0 - cd / p.ability_cooldown(i)
			draw_circle(c, r, Color(1.0, 0.6, 0.3, 0.28 if cd <= 0.0 else 0.1))
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * k, 28, Color(1.0, 0.7, 0.4, 0.85), 2.0)
			Abilities.draw_icon(self, p.actives[i]["id"], c, r * 1.1, Color(1, 0.9, 0.75, 0.95 if cd <= 0.0 else 0.4))
