extends SceneTree
## Preview: idle / glide / attack / dodge per class, every head and body piece, loot icons.
## Usage: godot --headless -s res://tools/gear_preview.gd -- out.png
var _img: Image
var _x := 8
var _y := 8
const S := 3

func _put(tex: Texture2D) -> void:
	var im := tex.get_image().duplicate() as Image
	im.resize(im.get_width() * S, im.get_height() * S, Image.INTERPOLATE_NEAREST)
	_img.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(_x, _y))
	_x += im.get_width() + 2

func _nl(h := 172) -> void:
	_x = 8
	_y += h

func _init() -> void:
	_img = Image.create(2000, 1400, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.18, 0.17, 0.22))
	for cls in ["fighter", "mage"]:
		var l: Dictionary = HeroArt.DEFAULT_LOOKS[cls]
		for f in 4:
			_put(Sprites.hero(cls, l, "idle", f))
		for f in 8:
			_put(Sprites.hero(cls, l, "walk", f))
		_nl()
	for cls in ["rogue", "archer"]:
		var l: Dictionary = HeroArt.DEFAULT_LOOKS[cls]
		for f in 4:
			_put(Sprites.hero(cls, l, "attack", f))
		for f in 4:
			_put(Sprites.hero(cls, l, "dodge", f))
		_put(Sprites.hero(cls, l, "hurt", 1))
		_put(Sprites.hero(cls, l, "death", 0))
		_put(Sprites.hero(cls, l, "death", 1))
		_nl()
	var l2: Dictionary = HeroArt.DEFAULT_LOOKS["fighter"].duplicate()
	for id in Gear.HEADS:
		var ll := l2.duplicate()
		ll["eq_head"] = id
		_put(Sprites.hero("fighter", ll, "idle", 0))
	for id in Gear.HEADS:
		_put(Sprites.gear_icon({"slot": "head", "id": id}))
	for id in Gear.BODIES:
		_put(Sprites.gear_icon({"slot": "body", "id": id}))
	_img.save_png(OS.get_cmdline_user_args()[0])
	quit()
