extends SceneTree
## Lists the bounding boxes of connected shapes in a PNG (to find animation frames).
func _init() -> void:
	var img := Image.load_from_file(OS.get_cmdline_user_args()[0])
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var boxes := []
	for y in h:
		for x in w:
			if seen[y * w + x] or img.get_pixel(x, y).a < 0.5:
				continue
			var r := Rect2i(x, y, 1, 1)
			var stack := [Vector2i(x, y)]
			seen[y * w + x] = 1
			var n := 0
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				n += 1
				r = r.expand(p)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var q := p + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
							continue
						if seen[q.y * w + q.x] or img.get_pixel(q.x, q.y).a < 0.5:
							continue
						seen[q.y * w + q.x] = 1
						stack.append(q)
			boxes.append([r.position.x, r.position.y, r.end.x + 1, r.end.y + 1, n])
	boxes.sort_custom(func(a, b): return a[1] < b[1] if absi(a[1] - b[1]) > 12 else a[0] < b[0])
	for b in boxes:
		if b[4] >= 3:
			print(b)
	quit()
