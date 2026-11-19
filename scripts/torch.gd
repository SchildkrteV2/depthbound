class_name Torch
extends Node2D
## Flickering wall torch with a real 2D light. Also used to build the shared light texture.

static var _light_tex: Texture2D

var light: PointLight2D
var _t := 0.0


static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_light_tex = t
	return _light_tex


## Makes a soft round light. `radius` is in pixels.
static func make_light(radius: float, color: Color, energy := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius / 128.0
	l.color = color
	l.energy = energy
	return l


func _ready() -> void:
	_t = randf() * 10.0
	light = make_light(80.0, Color(1.0, 0.72, 0.45), 0.45)
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	light.energy = 0.42 + 0.06 * sin(_t * 9.0) + 0.03 * sin(_t * 23.0)
	queue_redraw()


func _draw() -> void:
	Sprites.draw_at(self, Sprites.item("torch", int(_t * 8.0)), Vector2(0, 6))
