extends SceneTree
## Saves a zoomed crop of the source sheet: args x y w h zoom out.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/source/hero_sheet_preview.jpg"))
	var r := Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
	var c := img.get_region(r)
	c.resize(r.size.x * int(a[4]), r.size.y * int(a[4]), Image.INTERPOLATE_NEAREST)
	c.save_png(a[5])
	quit()
