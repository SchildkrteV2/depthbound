class_name DamageNumber
extends Node2D
## Floating damage number. Crits are bigger and gold.

const DURATION := 0.65

var text := ""
var crit := false
var _t := 0.0
var _drift := 0.0


func _ready() -> void:
	z_index = 20
	_drift = randf_range(-8.0, 8.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var font := ThemeDB.fallback_font
	var size := 12 if crit else 9
	var pop := 1.0 + (0.4 if crit else 0.2) * maxf(0.0, 1.0 - k * 5.0)
	var pos := Vector2(-40 + _drift * k, -10.0 - 18.0 * (1.0 - pow(1.0 - k, 2.0)))
	var col := Color(1.0, 0.82, 0.25) if crit else Color(1, 1, 1)
	col.a = 1.0 - maxf(0.0, k - 0.6) / 0.4
	var fs := int(size * pop)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 3, Color(0, 0, 0, col.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, col)
