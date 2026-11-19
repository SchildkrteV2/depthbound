class_name HeroArt
extends RefCounted
## The player heroes: little cartoon ghosts - a round head flowing into one long tail that
## curls at the tip, two flappy arms, hollow glowing eyes. No legs: they hover.
## The character creator picks the hat, the ghost colour and the eye glow; the only gear that
## shows on the ghost is headgear (helmets / hats that drop from monsters).
##
## Everything faces right; the game mirrors it for left. Each animation frame is a pose: hover
## bob, lean, how far the tail bends back and how it sways.

# ------------------------------------------------------------------ appearance options

const GHOST_COLORS := [
	Color(0.9, 0.94, 1.0), Color(0.97, 0.97, 0.96), Color(0.76, 1.0, 0.86), Color(0.86, 0.79, 1.0),
	Color(1.0, 0.82, 0.9), Color(1.0, 0.93, 0.7), Color(0.68, 0.86, 1.0), Color(0.6, 0.6, 0.7),
	Color(1.0, 0.76, 0.58),
]
## Eye glow. Index 0 = plain hollow eyes.
const EYE_COLORS := [
	Color(0.12, 0.14, 0.18), Color(0.4, 0.95, 1.0), Color(0.45, 1.0, 0.5), Color(1.0, 0.8, 0.3),
	Color(1.0, 0.3, 0.3), Color(0.75, 0.45, 1.0), Color(1.0, 0.5, 0.8), Color(0.95, 0.95, 1.0),
]
## Hats in the creator. "class" = the class's own (helmet / hood / cap / wizard hat).
const HATS := ["class", "none", "knight_helm", "iron_helm", "horned_helm", "class_hood", "shadow_hood",
	"cap", "class_hat", "arcane_hat", "crown", "bandana"]
const HAT_NAMES := {
	"class": "Class", "none": "None", "knight_helm": "Plumed Helm", "iron_helm": "Iron Helm",
	"horned_helm": "Horned Helm", "class_hood": "Hood", "shadow_hood": "Shadow Hood", "cap": "Feather Cap",
	"class_hat": "Wizard Hat", "arcane_hat": "Arcane Hat", "crown": "Crown", "bandana": "Bandana",
}
const NAMES := ["Mira", "Tobin", "Ash", "Kael", "Wren", "Juno", "Pip", "Rook", "Sable", "Fen",
	"Ivo", "Nell", "Bram", "Lyra", "Odo", "Quill", "Rhea", "Vex", "Yara", "Zed"]

## Unlocked through the Monster Codex: an eye glow at mastery II, a ghost colour at mastery III.
const CODEX_GHOST := {
	"slime": Color(0.6, 0.95, 0.5), "bat": Color(0.72, 0.55, 0.95), "spider": Color(0.6, 0.5, 0.45),
	"skeleton": Color(0.95, 0.92, 0.8), "bomber": Color(1.0, 0.6, 0.4), "ghost": Color(0.55, 0.75, 0.95),
	"wisp": Color(0.5, 1.0, 1.0), "cultist": Color(0.62, 0.35, 0.72), "brute": Color(0.92, 0.6, 0.45),
	"golem": Color(0.66, 0.63, 0.56), "boss": Color(0.95, 0.35, 0.42),
}
const CODEX_EYES := {
	"slime": Color(0.4, 1.0, 0.3), "bat": Color(0.85, 0.4, 1.0), "spider": Color(1.0, 0.2, 0.1),
	"skeleton": Color(0.7, 0.9, 1.0), "bomber": Color(1.0, 0.6, 0.1), "ghost": Color(0.6, 0.85, 1.0),
	"wisp": Color(0.2, 1.0, 0.9), "cultist": Color(1.0, 0.3, 1.0), "brute": Color(1.0, 0.45, 0.2),
	"golem": Color(1.0, 0.75, 0.3), "boss": Color(1.0, 0.1, 0.3),
}


## Every ghost colour / eye glow: the base ones, then one per codex monster (in codex order).
static func ghost_colors() -> Array:
	var a := GHOST_COLORS.duplicate()
	for k in Grind.CODEX_KINDS:
		a.append(CODEX_GHOST[k])
	return a


static func eye_colors() -> Array:
	var a := EYE_COLORS.duplicate()
	for k in Grind.CODEX_KINDS:
		a.append(CODEX_EYES[k])
	return a


## The codex monster behind a colour index ("" for the base colours).
static func codex_kind(key: String, i: int) -> String:
	var base := GHOST_COLORS.size() if key == "ghost" else EYE_COLORS.size()
	return "" if i < base else Grind.CODEX_KINDS[i - base]


static func color_unlocked(key: String, i: int) -> bool:
	var k := codex_kind(key, i)
	return k == "" or Grind.codex_tier(k) >= (3 if key == "ghost" else 2)


const DEFAULT_LOOKS := {
	"fighter": {"hat": "class", "ghost": 1, "eyes": 0},
	"rogue": {"hat": "class", "ghost": 7, "eyes": 4},
	"archer": {"hat": "class", "ghost": 2, "eyes": 2},
	"mage": {"hat": "class", "ghost": 3, "eyes": 5},
}


static func default_look(cls: String) -> Dictionary:
	var l: Dictionary = DEFAULT_LOOKS.get(cls, DEFAULT_LOOKS["fighter"]).duplicate()
	l["name"] = NAMES[randi() % NAMES.size()]
	return l


static func random_look() -> Dictionary:
	return {
		"hat": "class" if randf() < 0.4 else HATS[randi() % HATS.size()],
		"ghost": randi() % GHOST_COLORS.size(), "eyes": randi() % EYE_COLORS.size(),
		"name": NAMES[randi() % NAMES.size()],
	}


## A clean look for this version: fills in anything missing and drops/repairs anything from
## older versions (hair, outfits, numbers where names belong...).
static func complete(cls: String, look: Dictionary) -> Dictionary:
	var l := default_look(cls)
	if look.get("hat") is String and String(look["hat"]) in HATS:
		l["hat"] = look["hat"]
	if look.has("ghost"):
		l["ghost"] = clampi(int(look["ghost"]), 0, ghost_colors().size() - 1)
		if not color_unlocked("ghost", l["ghost"]):
			l["ghost"] = 0
	if look.has("eyes"):
		l["eyes"] = clampi(int(look["eyes"]), 0, eye_colors().size() - 1)
		if not color_unlocked("eyes", l["eyes"]):
			l["eyes"] = 0
	if look.get("name") is String and String(look["name"]) != "":
		l["name"] = look["name"]
	return l


# ------------------------------------------------------------------ painting
#
# Heroes are painted at high resolution from simple shapes straight into pixels. Sprites are
# drawn at half size in the world, so this gives twice the detail of the old grids.

const W := 40
const H := 58
const O := Vector2(21, 25) # head centre at rest (incl. 1px border)
const RX := 12.0
const RY := 11.0
## Where the weapon hand is, in world units from the feet (facing right).
const HAND := Vector2(6.0, -8.0)

const FRAMES := {"idle": 4, "walk": 8, "attack": 4, "hurt": 2, "dodge": 4, "death": 2}
## Kept for code that asks for the anim list.
const ANIMS := FRAMES


static func frame_count(anim: String) -> int:
	return int(FRAMES[anim])


static func palette(cls: String, look: Dictionary) -> Dictionary:
	var d := Classes.get_def(cls)
	return {
		"ghost": ghost_colors()[clampi(int(look.get("ghost", 0)), 0, ghost_colors().size() - 1)],
		"eye": eye_colors()[clampi(int(look.get("eyes", 0)), 0, eye_colors().size() - 1)],
		"hat": d["cloak"] as Color, "trim": d["trim"] as Color,
		"metal": Color(0.8, 0.83, 0.9), "red": Color(0.9, 0.24, 0.22), "gold": Color(0.98, 0.8, 0.3),
		"dark": Color(0.09, 0.07, 0.11), "white": Color(1, 1, 1), "leather": Color(0.5, 0.33, 0.2),
	}


## Body pose for one frame:
##   bx, by - body offset (hover bob, lean)    hx, hy - extra head offset
##   tail   - how far the tail bends back      sway  - tail wiggle    len - longer/shorter tail
##   arm, arm_b - front / back arm tip from the shoulder
static func pose(anim: String, f: int) -> Dictionary:
	var p := {"bx": 0.0, "by": 0.0, "hx": 0.0, "hy": 0.0, "tail": -4.0, "sway": 0.0, "len": 0.0,
		"arm": Vector2(3, 3), "arm_b": Vector2(-3, 3)}
	match anim:
		"idle":
			# Slow hover; the tail drifts from side to side.
			p["by"] = [0.0, -1.0, -2.0, -1.0][f]
			p["sway"] = [0.0, 1.5, 0.0, -1.5][f]
			p["arm"] = Vector2(3, 4.0 - [0.0, 1.0, 1.0, 0.0][f])
			p["arm_b"] = Vector2(-3, 4.0 - [0.0, 0.0, 1.0, 1.0][f])
		"walk":
			# Gliding: leans in, the tail streams out behind and swishes.
			var a := TAU * f / 8.0
			p["by"] = round(-1.0 - sin(a))
			p["bx"] = 1.0
			p["tail"] = -8.0
			p["sway"] = sin(a) * 2.0
			p["arm"] = Vector2(2.0 + sin(a), 4.0)
			p["arm_b"] = Vector2(-5.0 + sin(a), 3.0)
		"attack":
			p["arm"] = [Vector2(-6, 0), Vector2(8, 1), Vector2(7, 3), Vector2(3, 4)][f]
			p["bx"] = [-1.0, 2.0, 2.0, 0.0][f]
			p["hx"] = [-1.0, 1.0, 0.0, 0.0][f]
			p["tail"] = [-2.0, -9.0, -8.0, -5.0][f]
		"hurt":
			p["bx"] = -2.0 if f == 0 else -1.0
			p["hx"] = -1.0
			p["tail"] = 2.0
			p["len"] = -3.0
			p["arm"] = Vector2(-1, -3)
			p["arm_b"] = Vector2(-5, -1)
		"dodge":
			# A whoosh: stretches out long, then snaps back.
			p["by"] = [1.0, -1.0, -1.0, 0.0][f]
			p["bx"] = [0.0, 3.0, 3.0, 0.0][f]
			p["tail"] = [-4.0, -13.0, -11.0, -6.0][f]
			p["len"] = [-1.0, 3.0, 3.0, 0.0][f]
			p["arm"] = Vector2(-3, 3) if f == 1 or f == 2 else Vector2(3, 4)
		"death":
			p["bx"] = -2.0
			p["by"] = 0.0 if f == 0 else 6.0
			p["len"] = 0.0 if f == 0 else -9.0
			p["arm"] = Vector2(-3, -2) if f == 0 else Vector2(4, 2)
	return p


## Body offset of a frame in sprite pixels (the weapon hand follows the hover bob).
static func body_offset(anim: String, f: int) -> Vector2:
	var p := pose(anim, f % frame_count(anim))
	return Vector2(p["bx"], p["by"])


## Class headgear for look["hat"] == "class".
const CLASS_HEAD := {"fighter": "knight_helm", "rogue": "class_hood", "archer": "cap", "mage": "class_hat"}
## Bottom of the tail (sprite y) at rest; the sprite bottom is the ground, so it hovers.
const TAIL_Y := 50.0


## Which headgear a ghost wears: a dropped helmet beats the creator's hat.
static func head_kind(cls: String, look: Dictionary) -> String:
	var head := String(look.get("eq_head", ""))
	if head != "":
		return head
	var hat := String(look.get("hat", "class"))
	if hat == "class":
		return CLASS_HEAD.get(cls, "")
	return "" if hat == "none" else hat


## Paints one frame (with a 1px empty border for the outline).
static func image(cls: String, look: Dictionary, anim: String, f: int) -> Image:
	var c := palette(cls, look)
	var ghost: Color = c["ghost"]
	var head := head_kind(cls, look)
	var p := pose(anim, f % frame_count(anim))
	var img := Image.create(W + 2, H + 2, false, Image.FORMAT_RGBA8)
	var o := O + Vector2(p["bx"], p["by"]) # body anchor (head centre at rest)
	var h := o + Vector2(p["hx"], p["hy"]) # head centre this frame

	# Back arm (behind the body), a flappy little sleeve of sheet.
	var shb := o + Vector2(-RX + 4, 9)
	_flap(img, shb, shb + p["arm_b"], ghost.darkened(0.2))
	# The ghost: head flowing into one tail.
	_ghost_body(img, h, o, ghost, float(p["tail"]), float(p["sway"]), float(p["len"]), head == "")
	# Headgear.
	if head != "":
		_gear(img, h, head, c)
	# Two tall hollow eyes (the far one a bit smaller), glowing inside if an eye glow is
	# picked, and a small round "oh" mouth.
	var glow: Color = c["eye"]
	var hollow := glow.get_luminance() < 0.2
	var socket := Color(0.1, 0.11, 0.15)
	for ee in [[h + Vector2(1.5, 1.5), 0.85], [h + Vector2(7.0, 1.5), 1.0]]:
		var ep: Vector2 = (ee[0] as Vector2).round() # on the pixel grid: clean, even ovals
		var k: float = ee[1]
		_disc_e(img, ep, 2.3 * k, 3.4 * k, socket)
		if hollow:
			_px(img, int(ep.x) - 1, int(ep.y) - 2, Color(0.36, 0.4, 0.48)) # dull shine
		else:
			_disc_e(img, ep + Vector2(0, 1), 1.5 * k, 2.0 * k, glow.darkened(0.3))
			_px(img, int(ep.x) - 1, int(ep.y), glow.lightened(0.45))
			_px(img, int(ep.x) - 1, int(ep.y) + 1, glow)
			_px(img, int(ep.x), int(ep.y) + 1, glow)
			_px(img, int(ep.x), int(ep.y), glow)
	_disc_e(img, (h + Vector2(4.5, 8.0)).round(), 1.5, 1.3, socket)
	# Front arm over the body.
	var sh := o + Vector2(RX - 3, 9)
	_flap(img, sh, sh + p["arm"], ghost)
	return img


## A ghost arm: a soft flap of sheet that narrows to a rounded tip, with a slightly darker
## edge so it reads against the body.
static func _flap(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(ceil(a.distance_to(b) * 2.0)) + 2
	for pass_i in 2:
		for i in n:
			var t := float(i) / maxf(1.0, n - 1)
			var r := lerpf(2.8, 1.8, t) - (0.0 if pass_i == 0 else 0.9)
			_ellipse(img, a.lerp(b, t), r, r, col.darkened(0.22) if pass_i == 0 else col.lightened(0.06), false)


## The ghost shape: a dome head (its tip flopping back) over a short round belly; the lowest
## third is one wide tail that tapers, sweeps back and curls (like a classic cartoon ghost). Built as a mask,
## then shaded in two tones with a lit left edge and a shadow down the right side.
static func _ghost_body(img: Image, h: Vector2, o: Vector2, col: Color, tail: float, sway: float, len_add: float, peak := true) -> void:
	var w := img.get_width()
	var hh := img.get_height()
	var mask := PackedByteArray()
	mask.resize(w * hh)
	var stamp := func(c: Vector2, rx: float, ry: float) -> void:
		for y in range(maxi(0, floori(c.y - ry - 1)), mini(hh, ceili(c.y + ry + 1))):
			for x in range(maxi(0, floori(c.x - rx - 1)), mini(w, ceili(c.x + rx + 1))):
				var nx := (x + 0.5 - c.x) / rx
				var ny := (y + 0.5 - c.y) / ry
				if nx * nx + ny * ny <= 1.0:
					mask[y * w + x] = 1
	# Head: a slightly narrower dome, with the top of the sheet flopping back in a little point.
	stamp.call(h, RX * 0.9, RY)
	for i in (8 if peak else 0): # (hidden under hats)
		var t := i / 7.0
		stamp.call(h + Vector2(lerpf(-2.0, -9.0, t), lerpf(-8.0, -12.0, t * t)), lerpf(3.5, 1.2, t), lerpf(3.5, 1.2, t))
	# Short body: the head flows into a round belly that ends just below the arms...
	stamp.call(h + Vector2(1.0, 6.0), RX * 0.95, 7.5)
	# ...and the whole lower third is the tail: wide where it leaves the body, tapering to a
	# point as it sweeps back (and sways while floating).
	var top := h + Vector2(1.0, 10.0)
	var length := TAIL_Y + (o.y - O.y) + len_add - top.y
	var tip := top
	var steps := 40
	for i in steps + 1:
		var s := float(i) / steps
		var pt := Vector2(top.x + tail * 1.3 * pow(s, 1.4) + sway * sin(s * PI), top.y + s * length)
		var r := maxf(1.2, RX * 0.92 * pow(1.0 - s, 0.85))
		stamp.call(pt, r, r)
		tip = pt
	# Curl at the tip: down, back and up again.
	var back := -1.0 if tail <= 0.0 else 1.0
	var cr := 2.4
	var cc := tip + Vector2(back * cr, 0)
	for i in 10:
		var a := PI * 1.3 * i / 9.0
		stamp.call(cc + Vector2(-back * cos(a), sin(a)) * cr, 1.1, 1.1)
	# Two-tone fill.
	for y in hh:
		var minx := -1
		var maxx := -1
		for x in w:
			if mask[y * w + x] == 1:
				if minx < 0:
					minx = x
				maxx = x
		if minx < 0:
			continue
		var span := maxf(1.0, maxx - minx)
		for x in range(minx, maxx + 1):
			if mask[y * w + x] == 0:
				continue
			var u := (x - minx) / span
			var cc2 := col
			if x + 1 >= w or mask[y * w + x + 1] == 0 or u > 0.78:
				cc2 = col.darkened(0.16) # shadow side
			elif y > 0 and mask[(y - 1) * w + x] == 0 and u < 0.6:
				cc2 = col.lightened(0.3) # top highlight
			elif u < 0.14 and span > 6:
				cc2 = col.lightened(0.12) # lit edge
			if y > h.y + RY * 1.4:
				cc2 = cc2.darkened(0.05) # tail a touch darker
			_px(img, x, y, cc2)
	# A little shine on the head.
	_disc_e(img, h + Vector2(-5, -6), 1.6, 1.0, col.lightened(0.55))


## Armour colours (armour only shows on its loot icon - ghosts do not wear it).
const BODY_COLOR := {
	"chainmail": Color(0.6, 0.63, 0.7), "plate": Color(0.78, 0.81, 0.88), "leather": Color(0.58, 0.38, 0.23),
	"robe": Color(0.27, 0.34, 0.75), "blood_cloak": Color(0.52, 0.13, 0.18), "gilded_mail": Color(0.95, 0.74, 0.3),
}


## Loot icon for a dropped helmet / armour piece.
static func gear_icon(slot: String, id: String) -> Image:
	var c := palette("fighter", {})
	var img := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	if slot == "head":
		c["hat"] = Color(0.35, 0.3, 0.45)
		var hc := Vector2(15, 22)
		_ellipse(img, hc, RX * 0.85, RY * 0.5, Color(0.16, 0.13, 0.2), false) # empty inside
		_gear(img, hc, id, c)
	else:
		var oc: Color = BODY_COLOR.get(id, Color.GRAY)
		_rrect(img, Rect2(7, 9, 16, 16), 4.0, oc)
		_ellipse(img, Vector2(15, 9), 9.0, 3.0, oc.darkened(0.2))
		if id == "plate" or id == "gilded_mail":
			_ellipse(img, Vector2(9, 11), 4.0, 3.0, c["gold"] if id == "gilded_mail" else c["metal"])
			_ellipse(img, Vector2(21, 11), 4.0, 3.0, c["gold"] if id == "gilded_mail" else c["metal"])
		if id == "chainmail":
			for y in range(12, 24, 2):
				for x in range(9, 22, 2):
					_px(img, x + (y / 2) % 2, y, oc.darkened(0.3))
		_rrect(img, Rect2(7, 20, 16, 2), 0.0, c["leather"], false)
	return img




# ------------------------------------------------------------------ headgear

static func _helmet(img: Image, hc: Vector2, m: Color, rivets := true) -> void:
	for y in range(int(hc.y - RY * 1.2), int(hc.y)):
		for x in range(int(hc.x - RX * 1.2), int(hc.x + RX * 1.2)):
			var u := (x + 0.5 - hc.x) / RX
			var v := (y + 0.5 - hc.y) / RY
			var d := sqrt(u * u + v * v)
			if d < 1.12 and v < -0.3:
				var cc := _shade(m, u, v, d / 1.12)
				if v > -0.44:
					cc = m.darkened(0.3)
				elif rivets and (x == int(hc.x - 6) or x == int(hc.x + 4)) and y == int(hc.y - 6):
					cc = m.darkened(0.45)
				_px(img, x, y, cc)


static func _hood(img: Image, hc: Vector2, col: Color) -> void:
	_poly(img, PackedVector2Array([hc + Vector2(-RX * 0.9, -4), hc + Vector2(-RX - 8, 7), hc + Vector2(-RX * 0.5, RY * 0.9)]), col.darkened(0.1))
	for y in range(int(hc.y - RY * 1.3), int(hc.y + RY * 1.3)):
		for x in range(int(hc.x - RX * 1.3), int(hc.x + RX * 1.3)):
			var u := (x + 0.5 - hc.x) / RX
			var v := (y + 0.5 - hc.y) / RY
			var d := sqrt(u * u + v * v)
			var wu := (u - 0.42) / 0.62
			var wv := (v - 0.12) / 0.68
			var wd := sqrt(wu * wu + wv * wv)
			if d < 1.2 and wd > 1.0:
				var cc := _shade(col, u, v, d / 1.2)
				if wd < 1.2:
					cc = col.darkened(0.4) # shadow inside the hood
				_px(img, x, y, cc)


static func _hat(img: Image, hc: Vector2, hat: Color, band: Color) -> void:
	_ellipse(img, hc + Vector2(0, -5), RX + 5, 3.0, hat.darkened(0.12))
	_poly(img, PackedVector2Array([hc + Vector2(-9, -6), hc + Vector2(9, -6), hc + Vector2(3, -17), hc + Vector2(-7, -25), hc + Vector2(-3, -15)]), hat)
	_rrect(img, Rect2(hc.x - 8, hc.y - 9, 16, 2), 0.0, band, false)
	var s := hc + Vector2(0, -14)
	for dd in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_px(img, int(s.x + dd.x), int(s.y + dd.y), band)


## Headgear by kind: the class defaults (knight_helm, class_hood, cap, class_hat) and the
## droppable ones (see Gear.HEADS).
static func _gear(img: Image, hc: Vector2, kind: String, c: Dictionary) -> void:
	match kind:
		"knight_helm": # helmet with a plume
			_ellipse(img, hc + Vector2(-3, -RY - 1.5), 5.5, 3.4, c["red"])
			_helmet(img, hc, c["metal"])
		"iron_helm": # plain helmet with a nose guard
			_helmet(img, hc, Color(0.62, 0.65, 0.72))
			_rrect(img, Rect2(hc.x + 5, hc.y - 5, 2, 6), 0.0, Color(0.5, 0.52, 0.6), false)
		"horned_helm": # dark helmet with two horns
			var bone := Color(0.93, 0.88, 0.75)
			_poly(img, PackedVector2Array([hc + Vector2(-8, -7), hc + Vector2(-14, -12), hc + Vector2(-13, -17), hc + Vector2(-10, -11), hc + Vector2(-5, -9)]), bone)
			_poly(img, PackedVector2Array([hc + Vector2(5, -9), hc + Vector2(9, -14), hc + Vector2(8, -19), hc + Vector2(11, -13), hc + Vector2(8, -7)]), bone)
			_helmet(img, hc, Color(0.42, 0.4, 0.46))
		"class_hood":
			_hood(img, hc, c["hat"])
		"shadow_hood":
			_hood(img, hc, Color(0.22, 0.2, 0.3))
		"cap": # cap, brim and feather
			var cap: Color = c["hat"]
			_poly(img, PackedVector2Array([hc + Vector2(-5, -8), hc + Vector2(-9, -14), hc + Vector2(-11, -17), hc + Vector2(-8, -15), hc + Vector2(-3, -9)]), c["red"])
			for y in range(int(hc.y - RY * 1.2), int(hc.y)):
				for x in range(int(hc.x - RX * 1.2), int(hc.x + RX * 1.2)):
					var u := (x + 0.5 - hc.x) / RX
					var v := (y + 0.5 - hc.y) / RY
					var d := sqrt(u * u + v * v)
					if d < 1.1 and v < -0.32:
						_px(img, x, y, _shade(cap, u, v, d / 1.1))
			_poly(img, PackedVector2Array([hc + Vector2(2, -5), hc + Vector2(RX + 5, -3.5), hc + Vector2(RX + 4, -1.5), hc + Vector2(2, -2.5)]), cap.darkened(0.25))
		"class_hat":
			_hat(img, hc, c["hat"], c["gold"])
		"arcane_hat":
			_hat(img, hc, Color(0.2, 0.3, 0.78), Color(0.55, 0.95, 1.0))
		"crown":
			var g: Color = c["gold"]
			_rrect(img, Rect2(hc.x - 7, hc.y - RY - 1, 14, 4), 0.0, g)
			for i in 4:
				_poly(img, PackedVector2Array([hc + Vector2(-7 + i * 4, -RY - 1), hc + Vector2(-5.5 + i * 4, -RY - 6), hc + Vector2(-4 + i * 4, -RY - 1)]), g)
			_px(img, int(hc.x - 1), int(hc.y - RY + 1), c["red"])
			_px(img, int(hc.x + 3), int(hc.y - RY + 1), Color(0.3, 0.6, 1.0))
		"bandana":
			var r: Color = c["red"]
			_poly(img, PackedVector2Array([hc + Vector2(-RX, -6), hc + Vector2(RX - 1, -7), hc + Vector2(RX, -3), hc + Vector2(-RX, -2)]), r)
			_poly(img, PackedVector2Array([hc + Vector2(-RX + 1, -5), hc + Vector2(-RX - 6, -7), hc + Vector2(-RX - 5, -3), hc + Vector2(-RX - 7, 1), hc + Vector2(-RX + 1, -2)]), r.darkened(0.15))


# ------------------------------------------------------------------ shape painting

## 3-tone shading: light from the top left, darker towards the bottom right and the rim.
static func _shade(col: Color, nx: float, ny: float, edge: float) -> Color:
	var l := -0.6 * nx - 0.8 * ny
	if edge > 0.88 and l < 0.3:
		return col.darkened(0.28)
	if l > 0.5:
		return col.lightened(0.16)
	if l < -0.4:
		return col.darkened(0.16)
	return col


static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 1 and y >= 1 and x < img.get_width() - 1 and y < img.get_height() - 1:
		img.set_pixel(x, y, col)


static func _ellipse(img: Image, c: Vector2, rx: float, ry: float, col: Color, shaded := true) -> void:
	for y in range(floori(c.y - ry - 1), ceili(c.y + ry + 1)):
		for x in range(floori(c.x - rx - 1), ceili(c.x + rx + 1)):
			var nx := (x + 0.5 - c.x) / rx
			var ny := (y + 0.5 - c.y) / ry
			var d := nx * nx + ny * ny
			if d <= 1.0:
				_px(img, x, y, _shade(col, nx, ny, sqrt(d)) if shaded else col)


static func _disc_e(img: Image, c: Vector2, rx: float, ry: float, col: Color) -> void:
	_ellipse(img, c, rx, ry, col, false)


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	_ellipse(img, c, r, r, col, false)


static func _rrect(img: Image, r: Rect2, rad: float, col: Color, shaded := true) -> void:
	var ctr := r.get_center()
	for y in range(int(floor(r.position.y)), int(ceil(r.end.y))):
		for x in range(int(floor(r.position.x)), int(ceil(r.end.x))):
			var px := Vector2(x + 0.5, y + 0.5)
			if rad > 0.0:
				var q := Vector2(clampf(px.x, r.position.x + rad, r.end.x - rad), clampf(px.y, r.position.y + rad, r.end.y - rad))
				if px.distance_to(q) > rad:
					continue
			var nx := (px.x - ctr.x) / (r.size.x * 0.5)
			var ny := (px.y - ctr.y) / (r.size.y * 0.5)
			_px(img, x, y, _shade(col, nx, ny, maxf(absf(nx), absf(ny))) if shaded else col)


static func _poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	var rect := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		rect = rect.expand(q)
	var ctr := rect.get_center()
	for y in range(int(floor(rect.position.y)), int(ceil(rect.end.y)) + 1):
		for x in range(int(floor(rect.position.x)), int(ceil(rect.end.x)) + 1):
			var px := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(px, pts):
				var nx := (px.x - ctr.x) / maxf(1.0, rect.size.x * 0.5)
				var ny := (px.y - ctr.y) / maxf(1.0, rect.size.y * 0.5)
				_px(img, x, y, _shade(col, nx, ny, 0.0))


## A thick rounded line (arms, legs).
static func _limb(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var n := int(ceil(a.distance_to(b) * 2.0)) + 1
	for i in n:
		_disc(img, a.lerp(b, float(i) / maxf(1.0, n - 1)), w * 0.5, col)
