extends SceneTree
## Cuts the cleaned hero sheet (from sheet_extract.gd) into a uniform frame grid:
## one row per animation, 40x32 cells, body centred at x=20, feet on the bottom row.
## Usage: godot --headless -s res://tools/sheet_cut.gd -- <clean.png> <out.png>

## [name, ground y (exclusive), first cell x, frame count] in the clean 575x383 sheet.
const ROWS := [
	["walk", 70, 59, 6], ["run", 119, 59, 6], ["attack1", 168, 78, 4], ["idle", 216, 58, 4],
	["climb", 265, 58, 4], ["push", 313, 61, 6], ["dust", 363, 59, 6],
	["jump", 70, 314, 8], ["walk_attack", 119, 319, 6], ["hurt", 168, 316, 4], ["death", 217, 316, 8],
	["attack2", 265, 329, 6], ["throw", 313, 313, 4], ["dust2", 363, 315, 6],
]
const CW := 40
const CH := 32

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var src := Image.load_from_file(a[0])
	var out := Image.create(CW * 8, CH * ROWS.size(), false, Image.FORMAT_RGBA8)
	for r in ROWS.size():
		var name: String = ROWS[r][0]
		var ground: int = ROWS[r][1]
		var x0: int = ROWS[r][2]
		var n: int = ROWS[r][3]
		# Where the body sits in its cell: median left edge of the frames (ignores swipes).
		var lefts: Array[int] = []
		for k in n:
			var cell := Rect2i(x0 + 32 * k, ground - CH, 32, CH)
			var left := -1
			for x in range(cell.position.x, cell.end.x):
				for y in range(cell.position.y, cell.end.y):
					if src.get_pixel(x, y).a > 0.5:
						left = x - cell.position.x
						break
				if left >= 0:
					break
			if left >= 0:
				lefts.append(left)
		lefts.sort()
		var left_med := lefts[lefts.size() / 2] if not lefts.is_empty() else 5
		var dust := name.begins_with("dust")
		var shift := (CW - 32) / 2 if dust else 20 - (left_med + 10)
		for k in n:
			var cell := Rect2i(x0 + 32 * k, ground - CH, 32, CH)
			out.blit_rect(src, cell, Vector2i(k * CW + shift, r * CH))
		print(name, ": ", n, " frames, body offset ", left_med, " shift ", shift)
	out.save_png(a[1])
	quit()
