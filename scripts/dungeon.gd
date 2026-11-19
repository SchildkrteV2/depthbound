class_name Dungeon
extends Node2D
## Draws one floor, builds wall collision and an A* grid that enemies use to find paths.

const TILE := 16

var w := 0
var h := 0
var cells := PackedByteArray()
var biome: Dictionary = {}
var astar := AStarGrid2D.new()


func setup(data: Dictionary, biome_data: Dictionary) -> void:
	w = data["w"]
	h = data["h"]
	cells = data["cells"]
	biome = biome_data
	_build_collision()
	_build_astar()
	queue_redraw()


func is_floor(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and cells[y * w + x] == 1


func is_edge_wall(x: int, y: int) -> bool:
	if is_floor(x, y):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if is_floor(x + dx, y + dy):
				return true
	return false


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


## Returns world positions (cell centers) from `from` to `to`, excluding the start cell.
func find_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	if not is_floor(a.x, a.y) or not is_floor(b.x, b.y):
		return out
	var ids := astar.get_id_path(a, b)
	for i in range(1, ids.size()):
		out.append(Vector2(ids[i]) * TILE + Vector2(TILE, TILE) * 0.5)
	return out


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# Merge horizontal runs of wall tiles into single rectangles (far fewer shapes).
	for y in h:
		var x := 0
		while x < w:
			if not is_edge_wall(x, y):
				x += 1
				continue
			var start := x
			while x < w and is_edge_wall(x, y):
				x += 1
			var shape := RectangleShape2D.new()
			shape.size = Vector2((x - start) * TILE, TILE)
			var cs := CollisionShape2D.new()
			cs.shape = shape
			cs.position = Vector2((start + (x - start) / 2.0) * TILE, (y + 0.5) * TILE)
			body.add_child(cs)


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in h:
		for x in w:
			if not is_floor(x, y):
				astar.set_point_solid(Vector2i(x, y), true)


var _texture: ImageTexture


func _draw() -> void:
	if _texture == null:
		_bake()
	# Baked at 2x pixel density; drawn at half size.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(Sprites.PX, Sprites.PX))
	draw_texture(_texture, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Paints the whole floor into one image once, so the GPU draws a single texture
## per frame instead of thousands of rectangles (this was the main cause of lag).
func _bake() -> void:
	# Pixel-art tiles in this floor's colours (see Sprites.tileset), stamped into one image.
	var ts := Sprites.tileset(biome, TILE)
	var floors: Array = ts["floor"]
	var faces: Array = ts["face"]
	var tops: Array = ts["top"]
	var shadow: Image = ts["shadow"]
	var rim := (biome["wall"] as Color).darkened(0.45)
	var T: int = ts["size"] # art pixels per tile
	var full := Rect2i(0, 0, T, T)
	var img := Image.create(w * T, h * T, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var px := x * T
			var py := y * T
			var hsh := absi((x * 73856093) ^ (y * 19349663))
			if is_floor(x, y):
				# Mostly plain slabs; details (cracks, moss, bones...) now and then.
				var v := 0 if hsh % 5 != 0 else 1 + (hsh / 5) % 7
				img.blit_rect(floors[v], full, Vector2i(px, py))
				if not is_floor(x, y - 1):
					img.blend_rect(shadow, Rect2i(0, 0, T, 10), Vector2i(px, py))
			elif is_edge_wall(x, y):
				if is_floor(x, y + 1):
					# Front face of a wall (fake 3/4 view): brick wall with a stone lip.
					var fv := 0 if hsh % 3 != 0 else 1 + (hsh / 3) % 3
					img.blit_rect(faces[fv], full, Vector2i(px, py))
				else:
					img.blit_rect(tops[hsh % tops.size()], full, Vector2i(px, py))
					# Dark rim on the sides that touch the void.
					if not is_edge_wall(x - 1, y) and not is_floor(x - 1, y):
						img.fill_rect(Rect2i(px, py, 1, T), rim)
					if not is_edge_wall(x + 1, y) and not is_floor(x + 1, y):
						img.fill_rect(Rect2i(px + T - 1, py, 1, T), rim)
					if not is_edge_wall(x, y - 1) and not is_floor(x, y - 1):
						img.fill_rect(Rect2i(px, py, T, 1), rim)
	_texture = ImageTexture.create_from_image(img)
