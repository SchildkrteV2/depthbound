extends SceneTree
## Rebuilds the original pixel art from the upscaled JPEG preview of the hero sheet:
## samples each art pixel at its centre (scale 2.5, offset 1.15), clusters colours to clean
## JPEG noise, and makes the blue background transparent.
## Usage: godot --headless -s res://tools/sheet_extract.gd -- <out.png> [preview.png]

const SCALE := 2.5
const OFFSET := 1.15
const K := 14

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://assets/source/hero_sheet_preview.jpg"))
	var w := int((src.get_width() - OFFSET) / SCALE)
	var h := int((src.get_height() - OFFSET) / SCALE)
	var raw: Array[Color] = []
	for y in h:
		for x in w:
			var cx := OFFSET + (x + 0.5) * SCALE
			var cy := OFFSET + (y + 0.5) * SCALE
			# Average the 2x2 source pixels nearest the centre.
			var acc := Color(0, 0, 0, 0)
			for oy in [-0.5, 0.5]:
				for ox in [-0.5, 0.5]:
					acc += src.get_pixel(clampi(int(cx + ox), 0, src.get_width() - 1), clampi(int(cy + oy), 0, src.get_height() - 1))
			raw.append(acc / 4.0)
	# k-means palette.
	var centers: Array[Color] = []
	var seen := {}
	for c in raw:
		var key := Color(snappedf(c.r, 0.2), snappedf(c.g, 0.2), snappedf(c.b, 0.2))
		if not seen.has(key):
			seen[key] = true
			centers.append(c)
		if centers.size() >= K:
			break
	for it in 12:
		var sums: Array[Color] = []
		var counts: Array[int] = []
		for c in centers:
			sums.append(Color(0, 0, 0, 0))
			counts.append(0)
		for c in raw:
			var bi := _nearest(centers, c)
			sums[bi] += c
			counts[bi] += 1
		for i in centers.size():
			if counts[i] > 0:
				centers[i] = sums[i] / counts[i]
	var bg := src.get_pixel(5, 5)
	var bgi := _nearest(centers, bg)
	# JPEG halo clusters: anything close to the background blue counts as background;
	# pale blue-grey fringe gets merged into the nearest real (non-blue) colour.
	var is_bg := {}
	var remap := {}
	for i in centers.size():
		var c := centers[i]
		var db := sqrt((c.r - bg.r) ** 2 + (c.g - bg.g) ** 2 + (c.b - bg.b) ** 2)
		if db < 0.12:
			is_bg[i] = true
		elif (c.b - c.r > 0.15 and c.b > 0.6) or c.b - c.r > 0.2:
			remap[i] = true
	print("palette:")
	for i in centers.size():
		pass
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := _nearest(centers, raw[y * w + x])
			if is_bg.has(i):
				continue
			if remap.has(i):
				var alt: Array[Color] = []
				for j in centers.size():
					if not is_bg.has(j) and not remap.has(j) and j != bgi:
						alt.append(centers[j])
				var c2 := alt[_nearest(alt, raw[y * w + x])]
				c2.a = 1.0
				out.set_pixel(x, y, c2)
				continue
			if i != bgi:
				var c := centers[i]
				c.a = 1.0
				out.set_pixel(x, y, c)
	out.save_png(args[0])
	print("saved ", w, "x", h)
	if args.size() > 1:
		var big := out.duplicate() as Image
		big.resize(w * 3, h * 3, Image.INTERPOLATE_NEAREST)
		var bgimg := Image.create(w * 3, h * 3, false, Image.FORMAT_RGBA8)
		bgimg.fill(Color(0.2, 0.2, 0.25))
		bgimg.blend_rect(big, Rect2i(0, 0, w * 3, h * 3), Vector2i.ZERO)
		bgimg.save_png(args[1])
	quit()


func _nearest(centers: Array[Color], c: Color) -> int:
	var best := 0
	var bd := 1e9
	for i in centers.size():
		var d := (centers[i].r - c.r) ** 2 + (centers[i].g - c.g) ** 2 + (centers[i].b - c.b) ** 2
		if d < bd:
			bd = d
			best = i
	return best
