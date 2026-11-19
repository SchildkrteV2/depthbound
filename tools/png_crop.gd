extends SceneTree
## Zoomed crop of any PNG: args in.png x y w h zoom out.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	var c := img.get_region(Rect2i(int(a[1]), int(a[2]), int(a[3]), int(a[4])))
	c.resize(c.get_width() * int(a[5]), c.get_height() * int(a[5]), Image.INTERPOLATE_NEAREST)
	var bg := Image.create(c.get_width(), c.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.36, 0.56, 0.75))
	bg.blend_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i.ZERO)
	bg.save_png(a[6])
	quit()
