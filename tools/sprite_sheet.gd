extends SceneTree
## Renders every sprite onto one sheet (scaled 4x) so the art can be checked at a glance.
## Usage: godot --headless -s res://tools/sprite_sheet.gd -- <output.png>

var SCALE := 2

var _sheet: Image
var _x := 4
var _y := 4
var _row_h := 0


func _init() -> void:
	var out := "user://sprite_sheet.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1 and args[1] == "players":
		SCALE = 3
		_sheet = Image.create(1500, 2000, false, Image.FORMAT_RGBA8)
		_sheet.fill(Color(0.36, 0.56, 0.75))
		for cls in Classes.ORDER:
			var look: Dictionary = HeroArt.DEFAULT_LOOKS[cls]
			for anim in ["idle", "walk", "attack", "hurt", "dodge", "death"]:
				for f in HeroArt.frame_count(anim):
					_put(Sprites.hero(cls, look, anim, f, "white" if anim == "hurt" and f == 0 else ""))
				_gap()
			_newline()
		seed(7)
		for i in 14:
			_put(Sprites.hero(Classes.ORDER[i % 4], HeroArt.random_look(), "idle", 0))
		_newline()
		for hat in HeroArt.HATS:
			_put(Sprites.hero("archer", {"hat": hat, "ghost": 2, "eyes": 1}, "idle", 0))
		_sheet.save_png(out)
		quit()
		return
	_sheet = Image.create(900, 1900, false, Image.FORMAT_RGBA8)
	_sheet.fill(Color(0.16, 0.15, 0.19))
	for cls in Classes.ORDER:
		for anim in ["idle", "walk", "attack"]:
			for f in HeroArt.frame_count(anim):
				_put(Sprites.hero(cls, HeroArt.DEFAULT_LOOKS[cls], anim, f))
			_gap()
		_newline()
	for kind in ["slime", "slimelet", "bat", "spider", "ghost", "wisp"]:
		for f in (Sprites.ENEMY_FRAMES[kind] as Array).size():
			_put(Sprites.enemy(kind, f / float(Sprites.ENEMY_ANIM[kind]["fps"]) + 0.001, true) if false else _enemy_frame(kind, f))
		_put(_enemy_frame(kind, 0, "elite"))
		_put(_enemy_frame(kind, 0, "white"))
		_gap()
	_newline()
	for kind in ["skeleton", "bomber", "cultist", "brute", "golem"]:
		for f in 4:
			_put(Sprites.enemy(kind, f / 8.0 + 0.01, true))
		_put(Sprites.enemy(kind, 0.0, false, "elite"))
		_gap()
	_newline()
	var rng := RandomNumberGenerator.new()
	for i in 5:
		rng.seed = i * 7919
		var d := BossGen.generate(10 + i * 20, rng, ["bat", "slime"])
		_put(Sprites.boss(d, 0))
		_put(Sprites.boss(d, 1))
	_newline()
	for w in Sprites.WEAPONS:
		_put(Sprites.weapon(w))
	_newline()
	for it in Sprites.ITEMS:
		for f in Sprites.item_frames(it):
			_put(Sprites.item(it, f))
	_put(Sprites.stairs(false))
	_put(Sprites.stairs(true))
	_put(Sprites.orb(Color(0.85, 0.5, 1.0)))
	_put(Sprites.orb(Color(1.0, 0.55, 0.25)))
	_newline()
	var ts := Sprites.tileset({"floor": Color.from_hsv(0.6, 0.25, 0.22), "wall": Color.from_hsv(0.6, 0.3, 0.5), "wall_face": Color.from_hsv(0.6, 0.3, 0.5).darkened(0.4)}, 16)
	for img in ts["floor"]:
		_put_img(img)
	for img in ts["face"]:
		_put_img(img)
	for img in ts["top"]:
		_put_img(img)
	_newline()
	# A little room: face row on top, floor below.
	for x in 8:
		_put_img(ts["face"][x % 4])
	_newline()
	_sheet.save_png(out)
	print("saved ", out)
	quit()


func _enemy_frame(kind: String, f: int, variant := "") -> Texture2D:
	var seq: Array = Sprites.ENEMY_ANIM[kind]["seq"]
	var fps := float(Sprites.ENEMY_ANIM[kind]["fps"])
	var i := seq.find(f)
	return Sprites.enemy(kind, (i + 0.5) / fps, true, variant)


func _put(tex: Texture2D) -> void:
	_put_img(tex.get_image())


func _put_img(img: Image) -> void:
	var big := img.duplicate() as Image
	big.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	if _x + big.get_width() > _sheet.get_width():
		_newline()
	_sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(_x, _y))
	_x += big.get_width() + 4
	_row_h = maxi(_row_h, big.get_height())


func _gap() -> void:
	_x += 12


func _newline() -> void:
	_x = 4
	_y += _row_h + 8
	_row_h = 0
