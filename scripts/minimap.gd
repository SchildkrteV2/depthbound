class_name Minimap
extends Control
## Fog-of-war minimap. Reveals the area around the player as you explore and shows
## the stairs and events once you've seen them. Centred on the player.
## The explored map is kept in a small image (1 pixel per tile) that is only updated
## when you move to a new tile, so drawing it costs one texture per frame.

const CELL := 2.0
const REVEAL := 7
const FLOOR_COLOR := Color(0.7, 0.68, 0.75, 0.8)

var main: Node
var _explored := PackedByteArray()
var _last_cell := Vector2i(-999, -999)
var _img: Image
var _tex: ImageTexture
var _dirty := false
var _dungeon: Dungeon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func reset() -> void:
	_explored = PackedByteArray()
	_last_cell = Vector2i(-999, -999)
	_img = null
	_tex = null
	_dungeon = null
	if main and is_instance_valid(main.dungeon):
		_dungeon = main.dungeon
		_explored.resize(_dungeon.w * _dungeon.h)
		_explored.fill(0)
		_img = Image.create(_dungeon.w, _dungeon.h, false, Image.FORMAT_RGBA8)
		_img.fill(Color(0, 0, 0, 0))
		_tex = ImageTexture.create_from_image(_img)


func is_explored(c: Vector2i) -> bool:
	var d := _dungeon
	if d == null or c.x < 0 or c.y < 0 or c.x >= d.w or c.y >= d.h or _explored.is_empty():
		return false
	return _explored[c.y * d.w + c.x] == 1


func _process(_delta: float) -> void:
	if main == null or not is_instance_valid(main.dungeon) or not is_instance_valid(main.player):
		return
	if main.dungeon != _dungeon:
		reset()
	var d := _dungeon
	var c: Vector2i = d.world_to_cell(main.player.global_position)
	if c != _last_cell:
		_last_cell = c
		for y in range(maxi(c.y - REVEAL, 0), mini(c.y + REVEAL + 1, d.h)):
			for x in range(maxi(c.x - REVEAL, 0), mini(c.x + REVEAL + 1, d.w)):
				var i := y * d.w + x
				if _explored[i] == 0 and Vector2i(x - c.x, y - c.y).length_squared() <= REVEAL * REVEAL:
					_explored[i] = 1
					if d.is_floor(x, y):
						_img.set_pixel(x, y, FLOOR_COLOR)
						_dirty = true
		if _dirty:
			_tex.update(_img)
			_dirty = false
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.65, 0.52, 0.3, 0.6), false, 1.0)
	if _tex == null or main == null or not is_instance_valid(main.player):
		return
	var d := _dungeon
	var ppos: Vector2 = main.player.global_position
	var origin: Vector2 = size * 0.5 - ppos / Dungeon.TILE * CELL
	draw_texture_rect(_tex, Rect2(origin, Vector2(d.w, d.h) * CELL), false)
	# Stairs and events, once discovered.
	if is_instance_valid(main.stairs):
		var sc := d.world_to_cell(main.stairs.global_position)
		if is_explored(sc):
			var col := Color(0.9, 0.2, 0.25) if main.stairs.locked else Color(1.0, 0.85, 0.3)
			draw_rect(Rect2(origin + Vector2(sc) * CELL - Vector2(2, 2), Vector2(5, 5)), col)
	if is_instance_valid(main.elevator):
		var lc := d.world_to_cell(main.elevator.global_position)
		if is_explored(lc):
			draw_rect(Rect2(origin + Vector2(lc) * CELL - Vector2(2, 2), Vector2(5, 5)), Color(0.4, 1.0, 0.5))
	for ev in get_tree().get_nodes_in_group("events"):
		var ec := d.world_to_cell(ev.global_position)
		if is_explored(ec):
			draw_circle(origin + Vector2(ec) * CELL + Vector2(1, 1), 2.5, Color(0.4, 0.9, 1.0) if not ev.used else Color(0.4, 0.4, 0.45))
	draw_circle(size * 0.5, 2.5, Color(0.4, 0.6, 1.0))
	draw_arc(size * 0.5, 3.0, 0.0, TAU, 10, Color.WHITE, 1.0)
