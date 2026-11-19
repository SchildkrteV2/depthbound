class_name AbilityBar
extends Control
## HUD row of devoured powers: 4 active slots (key hint + cooldown sweep) and
## 4 passive slots, plus curse markers. Empty slots are shown dimmed.

const SLOT := 20.0
const GAP := 3.0
const KEYS := ["Q", "E", "R", "F"]

var hud: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var p: Player = hud.player if hud else null
	if not is_instance_valid(p):
		return
	var font := ThemeDB.fallback_font
	var touch: bool = hud.get_parent().touch.active if hud.get_parent().get("touch") else false
	for i in Abilities.MAX_ACTIVES:
		var r := Rect2(i * (SLOT + GAP), 0, SLOT, SLOT)
		draw_rect(r, Color(0, 0, 0, 0.55))
		if i < p.actives.size():
			var ab: Dictionary = p.actives[i]
			var ready := p.ability_cd[i] <= 0.0
			Abilities.draw_icon(self, ab["id"], r.get_center(), SLOT * 0.7, Abilities.ACTIVE_COLOR if ready else Color(0.5, 0.45, 0.4))
			if not ready:
				var k := p.ability_cd[i] / p.ability_cooldown(i)
				draw_rect(Rect2(r.position, Vector2(SLOT, SLOT * k)), Color(0, 0, 0, 0.55))
			draw_rect(r, Abilities.ACTIVE_COLOR, false, 1.0)
		else:
			draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)
		if not touch:
			draw_string(font, r.position + Vector2(1, SLOT - 1), KEYS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.8))
	var y := SLOT + GAP
	for i in Abilities.MAX_PASSIVES:
		var r := Rect2(i * (SLOT * 0.75 + GAP), y, SLOT * 0.75, SLOT * 0.75)
		draw_rect(r, Color(0, 0, 0, 0.55))
		if i < p.passives.size():
			Abilities.draw_icon(self, p.passives[i]["id"], r.get_center(), SLOT * 0.5, Abilities.PASSIVE_COLOR)
			draw_rect(r, Abilities.PASSIVE_COLOR, false, 1.0)
		else:
			draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)
	# Curses (from plunging) as red marks after the passives.
	var cx := Abilities.MAX_PASSIVES * (SLOT * 0.75 + GAP) + 4.0
	if not p.curses.is_empty():
		draw_string(font, Vector2(cx, y + 11), "Curses: %d" % p.curses.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.4, 0.6))
