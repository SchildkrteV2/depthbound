class_name DragScroll
extends Node
## Lets you scroll a ScrollContainer by dragging anywhere on the screen (finger or mouse),
## not just on the scroll bar, with a little momentum after you let go. Short taps still
## press buttons; once a drag passes THRESHOLD the pressed button is cancelled.

const THRESHOLD := 8.0
const FRICTION := 6.0

var scroll: ScrollContainer
var _down := false
var _dragging := false
var _start := Vector2.ZERO
var _start_scroll := 0.0
var _last_y := 0.0
var _vel := 0.0
var _pos := 0.0
var _last_ms := 0


func _init(target: ScrollContainer) -> void:
	scroll = target


func _input(event: InputEvent) -> void:
	if not is_instance_valid(scroll) or not scroll.is_visible_in_tree():
		_down = false
		_dragging = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x < -9000.0:
			return # our own synthetic release (see _cancel_press)
		if event.pressed:
			_down = true
			_dragging = false
			_vel = 0.0
			_start = event.position
			_start_scroll = scroll.scroll_vertical
			_pos = _start_scroll
			_last_y = event.position.y
			_last_ms = Time.get_ticks_msec()
		else:
			if _dragging:
				get_viewport().set_input_as_handled()
			_down = false
			_dragging = false
	elif event is InputEventMouseMotion and _down:
		if not _dragging and absf(event.position.y - _start.y) > THRESHOLD:
			_dragging = true
			_cancel_press()
		if _dragging:
			var now := Time.get_ticks_msec()
			var dt := maxf(0.001, (now - _last_ms) / 1000.0)
			var dy: float = event.position.y - _last_y
			_vel = lerpf(_vel, -dy / dt, 0.5)
			_last_y = event.position.y
			_last_ms = now
			_pos = _start_scroll - (event.position.y - _start.y)
			scroll.scroll_vertical = int(round(_pos))
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _dragging or _down or absf(_vel) < 5.0 or not is_instance_valid(scroll):
		return
	# Momentum after a flick.
	_pos = scroll.scroll_vertical + _vel * delta
	scroll.scroll_vertical = int(round(_pos))
	_vel *= exp(-FRICTION * delta)


## Tells the GUI the press ended somewhere far away, so the button under the finger
## doesn't fire when the drag ends.
func _cancel_press() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = Vector2(-10000, -10000)
	ev.global_position = ev.position
	get_viewport().push_input.call_deferred(ev)
