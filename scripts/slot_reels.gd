class_name SlotReels
extends Control
## The three spinning reels of the Cursed Idol (slot machine). Lives in the HUD dialog.
## spin(targets) spins, stops the reels left to right, then emits `stopped`.

signal stopped
signal reel_stopped(i: int)

const SYMBOLS := ["coin", "heart", "sword", "gem", "skull"]
const BOX := Vector2(46, 46)
const GAP := 10.0
const STOP_AT := [0.9, 1.35, 1.8] # seconds after the pull

var shown := [0, 1, 4]
var _targets := [0, 0, 0]
var _t := -1.0
var _done := [true, true, true]
var _flash := 0.0
var _win := false


func _init() -> void:
	custom_minimum_size = Vector2(BOX.x * 3 + GAP * 2 + 20, BOX.y + 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


static func icon(sym: String) -> Texture2D:
	match sym:
		"sword":
			return Sprites.weapon("sword")
		"gem":
			return Sprites.item("sym_gem")
		"skull":
			return Sprites.item("sym_skull")
	return Sprites.item(sym)


func spinning() -> bool:
	return _t >= 0.0


func spin(targets: Array, win := false) -> void:
	_targets = targets.duplicate()
	_done = [false, false, false]
	_t = 0.0
	_win = win
	_flash = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_flash = maxf(_flash - delta, 0.0)
	if _t >= 0.0:
		_t += delta
		for i in 3:
			if not _done[i] and _t >= STOP_AT[i]:
				_done[i] = true
				shown[i] = _targets[i]
				reel_stopped.emit(i)
		if _done.all(func(d: bool) -> bool: return d):
			_t = -1.0
			if _win:
				_flash = 1.2
			stopped.emit()
	queue_redraw()


func _draw() -> void:
	var w := BOX.x * 3 + GAP * 2
	var x0 := (size.x - w) * 0.5
	var frame_col := Color(1.0, 0.85, 0.35) if _flash > 0.0 and int(_flash * 8.0) % 2 == 0 else Color(0.6, 0.48, 0.28)
	draw_rect(Rect2(x0 - 6, 2, w + 12, BOX.y + 12), Color(0.05, 0.04, 0.07))
	draw_rect(Rect2(x0 - 6, 2, w + 12, BOX.y + 12), frame_col, false, 2.0)
	for i in 3:
		var r := Rect2(Vector2(x0 + i * (BOX.x + GAP), 8), BOX)
		draw_rect(r, Color(0.86, 0.82, 0.74))
		draw_rect(r, Color(0.3, 0.24, 0.18), false, 2.0)
		var spinning_now: bool = _t >= 0.0 and not _done[i]
		if spinning_now:
			# Symbols scroll past quickly; slow down just before stopping.
			var speed := lerpf(16.0, 7.0, clampf(_t / float(STOP_AT[i]), 0.0, 1.0))
			var pos := _t * speed + i * 1.7
			var k := int(pos)
			var frac := pos - k
			var step := 34.0
			for j in [-1, 0, 1]:
				var sym: String = SYMBOLS[posmod(k - j, SYMBOLS.size())]
				var dy: float = (frac + j) * step - step * 0.5
				if absf(dy) < r.size.y * 0.5 - 6.0:
					var fade := 1.0 - absf(dy) / (r.size.y * 0.5)
					_draw_symbol(sym, Vector2(r.get_center().x, r.get_center().y + dy), Color(1, 1, 1, 0.35 + 0.6 * fade))
		else:
			_draw_symbol(SYMBOLS[shown[i]], r.get_center(), Color.WHITE)
		# Glass shine.
		draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 4)), Color(1, 1, 1, 0.25))


func _draw_symbol(sym: String, center: Vector2, mod: Color) -> void:
	var tex := icon(sym)
	var s := 28.0 / maxf(tex.get_width(), tex.get_height())
	var ang := -PI / 4.0 if sym == "sword" else 0.0
	draw_set_transform(center, ang, Vector2(s, s))
	draw_texture(tex, -(tex.get_size() / 2.0).round(), mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
