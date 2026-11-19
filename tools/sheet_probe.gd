extends SceneTree
## Finds the pixel grid (scale + offset) of an upscaled pixel-art image by checking where
## colour edges fall.

func _init() -> void:
	var path := ProjectSettings.globalize_path("res://assets/source/hero_sheet_preview.jpg")
	var img := Image.load_from_file(path)
	print("size ", img.get_size(), " bg ", img.get_pixel(5, 5), " ", img.get_pixel(700, 50))
	for axis in 2:
		var edges: Array[int] = []
		var w := img.get_width() if axis == 0 else img.get_height()
		var strength := PackedFloat32Array()
		strength.resize(w)
		for i in range(1, w):
			var s := 0.0
			for j in range(0, (img.get_height() if axis == 0 else img.get_width()), 2):
				var a := img.get_pixel(i, j) if axis == 0 else img.get_pixel(j, i)
				var b := img.get_pixel(i - 1, j) if axis == 0 else img.get_pixel(j, i - 1)
				var d := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				if d > 0.35:
					s += 1.0
			strength[i] = s
		var best := [0.0, 0.0, 0.0]
		var sc := 2.3
		while sc <= 2.7:
			var o := 0.0
			while o < sc:
				var on := 0.0
				var total := 0.0
				for i in w:
					if strength[i] <= 0.0:
						continue
					total += strength[i]
					var r := fposmod(i - o, sc)
					if r < 0.5 or r > sc - 0.5:
						on += strength[i]
				var score := on / maxf(total, 1.0)
				if score > best[0]:
					best = [score, sc, o]
				o += 0.025
			sc += 0.002
		print("axis ", axis, " best score/scale/offset ", best)
	quit()
