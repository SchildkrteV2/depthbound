class_name Sprites
extends RefCounted
## All pixel art in the game.
##
## Sprites are written as text grids: one character = one pixel, "." = transparent, and each
## letter is looked up in a palette. Textures are built the first time they are used and cached.
## Every sprite gets a 1-pixel dark outline automatically (gold for elites, white flash on hit).
## Walking characters are built from a body + leg frames + a 1px bob, so a 4-frame walk cycle
## only needs the body drawn once.

const OUTLINE := Color(0.05, 0.04, 0.07)
const ELITE_OUTLINE := Color(1.0, 0.8, 0.25)

static var _cache := {}

## Shared palette. Sprites override letters with their own colours.
const BASE_PAL := {
	"S": Color(0.96, 0.8, 0.62), "s": Color(0.78, 0.58, 0.45), "E": Color(0.1, 0.08, 0.14),
	"k": Color(0.07, 0.06, 0.09), "B": Color(0.3, 0.2, 0.13), "P": Color(0.3, 0.28, 0.36),
	"p": Color(0.22, 0.2, 0.27), "W": Color(0.96, 0.95, 0.9), "R": Color(0.88, 0.24, 0.2),
	"H": Color(0.42, 0.26, 0.15), "G": Color(0.95, 0.78, 0.3), "Y": Color(1.0, 0.92, 0.45),
	"M": Color(0.8, 0.83, 0.9), "m": Color(0.52, 0.55, 0.64), "b": Color(0.55, 0.37, 0.22),
}

# ============================================================== player

## Player heroes (see HeroArt): class + creator look + animation frame.
static func hero(cls: String, look: Dictionary, anim: String, frame: int, variant := "") -> Texture2D:
	var f := frame % HeroArt.frame_count(anim)
	var key := "h/%s/%s/%s/%d/%s" % [cls, look_key(look), anim, f, variant]
	if not _cache.has(key):
		_cache[key] = _finish(HeroArt.image(cls, look, anim, f), variant)
	return _cache[key]




## Builds every animation frame of a hero up front (avoids small hitches mid-fight).
static func prewarm_hero(cls: String, look: Dictionary) -> void:
	for anim in HeroArt.FRAMES:
		for f in HeroArt.frame_count(anim):
			hero(cls, look, anim, f)
	hero(cls, look, "hurt", 0, "white")
	hero(cls, look, "death", 0, "white")


## Loot icon for a dropped gear piece (weapons use their own sprite).
static func gear_icon(item: Dictionary) -> Texture2D:
	if item.get("slot") == "weapon":
		return weapon(String(item["weapon"]))
	var key := "gi/%s/%s" % [item["slot"], item["id"]]
	if not _cache.has(key):
		_cache[key] = _finish(HeroArt.gear_icon(String(item["slot"]), String(item["id"])), "")
	return _cache[key]


static func look_key(look: Dictionary) -> String:
	return "%s.%d.%d.%s" % [look.get("hat", "class"), int(look.get("ghost", 0)), int(look.get("eyes", 0)), look.get("eq_head", "")]


# ============================================================== enemies

## Frame-by-frame enemies.
const ENEMY_FRAMES := {
	"slime": [
		[
			"....GGGG....",
			"..GGLLGGGG..",
			".GLWLGGGGGg.",
			".GGLGGGGGGg.",
			"GGGEGGGGEGgg",
			"GGGEGGGGEGgg",
			"gGGGGGGGGGgg",
			".gggggggggg.",
		],
		[
			"...GGGGGG...",
			".GGLLGGGGGg.",
			"GLWLGGGGGGgg",
			"GGGEGGGGEGgg",
			"GGGEGGGGEGgg",
			"gGGGGGGGGGgg",
			"gggggggggggg",
		],
		[
			".....GG.....",
			"....GGGG....",
			"...GLLGGg...",
			"..GLWGGGGg..",
			"..GLGGGGGg..",
			"..GEGGGGEg..",
			"..GEGGGGEg..",
			"..gGGGGGgg..",
			"...gggggg...",
		],
	],
	"slimelet": [
		["..GGGG..", ".GWLGGg.", "GGEGGEGg", "gGGGGGgg", ".gggggg."],
		[".GGGGGG.", "GWLGGGGg", "GGEGGEGg", "gggggggg"],
		["...GG...", "..GGGg..", ".GWGGGg.", ".GEGEGg.", ".gGGGgg.", "..gggg.."],
	],
	"bat": [
		[
			"p.............p",
			"pp...P...P...pp",
			"ppp..PPPPP..ppp",
			".ppppPRPRPpppp.",
			"..pppPPPPPppp..",
			".....PWPWP.....",
			"......PPP......",
		],
		[
			".....P...P.....",
			".....PPPPP.....",
			"pppppPRPRPppppp",
			".ppppPPPPPpppp.",
			"..p..PWPWP..p..",
			"......PPP......",
		],
		[
			".....P...P.....",
			".....PPPPP.....",
			"....pPRPRPp....",
			"...ppPPPPPpp...",
			"..pppPWPWPppp..",
			".ppp..PPP..ppp.",
			"pp...........pp",
		],
	],
	"spider": [
		[
			"...l.......l...",
			"l...l.RBR.l...l",
			".l...BBBBB...l.",
			"..llBBLBBBBll..",
			"llllBLLBBBbllll",
			"...lBBBBBBbl...",
			"..l.bBBBBbb.l..",
			".l...bbbbb...l.",
			"l.............l",
		],
		[
			"..l.........l..",
			".l..l.RBR.l..l.",
			"l....BBBBB....l",
			".lllBBLBBBBlll.",
			"lll.BLLBBBb.lll",
			"..llBBBBBBbll..",
			".l..bBBBBbb..l.",
			"l....bbbbb....l",
		],
	],
	"ghost": [
		[
			"...WWWWWw...",
			"..WWWWWWWw..",
			".WWWWWWWWWw.",
			".WWkkWWkkWw.",
			".WWkkWWkkWw.",
			".WWWWWWWWWw.",
			".WWWWkkWWWw.",
			".WWWWWWWWWw.",
			".WWWWWWWWww.",
			".WW.WWW.WWw.",
			".W...W...w..",
		],
		[
			"...WWWWWw...",
			"..WWWWWWWw..",
			".WWWWWWWWWw.",
			".WWkkWWkkWw.",
			".WWkkWWkkWw.",
			".WWWWWWWWWw.",
			".WWWWkkWWWw.",
			".WWWWWWWWWw.",
			".WWWWWWWWww.",
			".WWW.WWW.Ww.",
			"..W...W...w.",
		],
	],
	"wisp": [
		["....F....", "...FF....", "...FLF.F.", "..FLLFFF.", ".FLWWLFf.", ".FLkWkLf.", ".FLWWLFf.", "..fLLFf..", "...fff..."],
		[".....F...", "....FF...", ".F.FLF...", ".FFLLFF..", ".FLWWLFf.", ".FLkWkLf.", ".FLWWLFf.", "..fLLFf..", "...fff..."],
		["...F.....", "...FF..F.", "..FLFFF..", "..FLLFF..", ".FLWWLFf.", ".FLkWkLf.", ".FLWWLFf.", "..fLLFf..", "...fff..."],
	],
}

## How frame-by-frame enemies animate. "always": animates even while standing still.
const ENEMY_ANIM := {
	"slime": {"seq": [0, 1, 0, 2], "fps": 5.0, "always": true},
	"slimelet": {"seq": [0, 1, 0, 2], "fps": 7.0, "always": true},
	"bat": {"seq": [0, 1, 2, 1], "fps": 14.0, "always": true},
	"spider": {"seq": [0, 1], "fps": 10.0},
	"ghost": {"seq": [0, 1], "fps": 3.0, "always": true},
	"wisp": {"seq": [0, 1, 0, 2], "fps": 8.0, "always": true},
}

## Walking enemies: body + legs, like the player.
const ENEMY_WALKERS := {
	"skeleton": {
		"body": [
			"...WWWW...",
			"..WWWWWW..",
			"..WkWWkW..",
			"..WWWWWw..",
			"...wkwk...",
			"....WW....",
			".wWWWWWWw.",
			".W.wWWw.W.",
			".W.WwwW.W.",
			"...WwwW...",
		],
		"legs": {
			"idle": ["...W..W...", "...W..W...", "..WW..WW.."],
			"a": ["...W..W...", "..WW..W...", "......WW.."],
			"b": ["...W..W...", "...W..WW..", "..WW......"],
			"seq": [["a", 1], ["idle", 0], ["b", 1], ["idle", 0]],
		},
	},
	"bomber": {
		"body": [
			"G..GGGG..G",
			".GGGGGGGG.",
			"..GYGGYg..",
			"..GGkkGg..",
			"...gggg...",
			"..bbbbbb..",
			".GbbbbbbG.",
			"..bbbbbb..",
		],
		"legs": {
			"idle": ["...g..g...", "...g..g...", "..kk..kk.."],
			"a": ["...g..g...", "..kk..g...", "......kk.."],
			"b": ["...g..g...", "...g..kk..", "..kk......"],
			"seq": [["a", 1], ["idle", 0], ["b", 1], ["idle", 0]],
		},
	},
	"cultist": {
		"body": [
			"....rr....",
			"...rRRr...",
			"..rRRRRr..",
			"..RkkkkR..",
			"..REkkER..",
			"..rkkkkr..",
			".rRRGGRRr.",
			"rRRRGGRRRr",
			"PRRRGGRRRP",
			".RRRGGRRr.",
		],
		"legs": {
			"idle": [".RRRRRRRr.", "rRRRRRRRRr"],
			"a": [".RRRRRRRr.", "rRrRRrRRrr"],
			"b": [".rRRRRRRR.", "rrRRrRRrRr"],
			"seq": [["a", 0], ["idle", 0], ["b", 0], ["idle", 0]],
		},
	},
	"brute": {
		"body": [
			"..H............H..",
			"..HH..........HH..",
			"...HHoOOOOOOoHH...",
			"....oOOOOOOOOo....",
			"....OOYOOOOYOo....",
			"....OOOOOOOOOo....",
			"....oOTOTTOTOo....",
			"...ooOOOOOOOOoo...",
			".oOOOOlOOOOlOOOOo.",
			"oOOOOOOOOOOOOOOOOo",
			"OOO.oOOOOOOOOo.OOO",
			"OOO.KKKKKKKKKK.OOo",
			".o..KKKKKKKKKK..o.",
		],
		"legs": {
			"idle": [".....OOO..OOO.....", ".....OOO..OOO.....", "....ooOO..OOoo...."],
			"a": [".....OOO..OOO.....", ".....ooo..OOO.....", "..........OOoo...."],
			"b": [".....OOO..OOO.....", ".....OOO..ooo.....", "....ooOO.........."],
			"seq": [["a", 1], ["idle", 0], ["b", 1], ["idle", 0]],
		},
	},
	"golem": {
		"body": [
			".......LLLLLL.......",
			".....LLSSSSSSs......",
			"....LSSSSSSSSSs.....",
			"....SSYSSSSYSSs.....",
			"....SSSSkSSSSSs.....",
			"..LLLssSSSSSSssLLL..",
			".LSSSSSSSkSSSSSSSs..",
			"LSSSsSSSFFSSSsSSSSs.",
			"SSSSsSSFFFFSSsSSSSs.",
			"SSSssSSSFFSSSssSSSs.",
			"sSS.sSSSSSSSSs.sSSs.",
			"sss..sSSSSSSSs..sss.",
		],
		"legs": {
			"idle": ["......SSS..SSS......", "......sSS..SSs......", ".....ssss..ssss....."],
			"a": ["......SSS..SSS......", "......sss..SSs......", "...........ssss....."],
			"b": ["......SSS..SSS......", "......sSS..sss......", ".....ssss..........."],
			"seq": [["a", 1], ["idle", 0], ["b", 1], ["idle", 0]],
		},
	},
}


static func _enemy_pal(kind: String) -> Dictionary:
	var c: Color = Enemy.TYPES[kind]["color"]
	var p := BASE_PAL.duplicate()
	var dark := c.darkened(0.35)
	var light := c.lightened(0.35)
	match kind:
		"slime", "slimelet":
			p.merge({"G": c, "g": dark, "L": light, "W": Color(1, 1, 1)}, true)
		"bat":
			p.merge({"P": c, "p": dark, "R": Color(1.0, 0.3, 0.3)}, true)
		"spider":
			p.merge({"B": c, "b": dark, "L": light, "l": c.darkened(0.55), "R": Color(1.0, 0.25, 0.2)}, true)
		"skeleton":
			p.merge({"W": c, "w": c.darkened(0.28)}, true)
		"bomber":
			p.merge({"G": c, "g": dark, "Y": Color(1.0, 0.9, 0.3), "b": Color(0.45, 0.3, 0.18)}, true)
		"ghost":
			p.merge({"W": c, "w": c.darkened(0.2), "k": Color(0.1, 0.1, 0.28)}, true)
		"wisp":
			p.merge({"F": c, "f": dark, "L": light, "W": Color(1, 1, 1), "k": Color(0.05, 0.2, 0.25)}, true)
		"cultist":
			p.merge({"R": c, "r": dark, "E": Color(1.0, 0.4, 1.0), "P": Color(0.85, 0.78, 0.7)}, true)
		"brute":
			p.merge({"O": c, "o": dark, "l": light, "H": Color(0.92, 0.88, 0.75), "Y": Color(1.0, 0.9, 0.3), "K": Color(0.4, 0.27, 0.15), "T": Color(1, 1, 0.92)}, true)
		"golem":
			p.merge({"S": c, "s": dark, "L": light, "k": c.darkened(0.6), "F": Color(1.0, 0.55, 0.2), "Y": Color(1.0, 0.7, 0.3)}, true)
	return p


## Picks the right animation frame. `t` is the enemy's own clock in seconds.
static func enemy(kind: String, t: float, moving: bool, variant := "") -> Texture2D:
	var idx := 0
	if ENEMY_WALKERS.has(kind):
		idx = (int(t * 8.0) % 4) if moving else 4 + int(t * 2.0) % 2
	elif ENEMY_ANIM.has(kind):
		var a: Dictionary = ENEMY_ANIM[kind]
		if moving or a.get("always", false):
			var seq: Array = a["seq"]
			idx = seq[int(t * float(a["fps"])) % seq.size()]
	var key := "e/%s/%d/%s" % [kind, idx, variant]
	if not _cache.has(key):
		var rows: Array
		if ENEMY_WALKERS.has(kind):
			rows = _walker(ENEMY_WALKERS[kind]["body"], ENEMY_WALKERS[kind]["legs"], idx)
		else:
			rows = ENEMY_FRAMES[kind][idx]
		_cache[key] = _finish(_image(rows, _enemy_pal(kind)), variant)
	return _cache[key]


# ============================================================== bosses

## Bosses are generated, so their sprite is painted pixel by pixel from the look data.
## Two frames: normal and a slightly squashed "breath".
static func boss(d: Dictionary, frame: int, variant := "") -> Texture2D:
	var key := "b/%s/%d/%s" % [d.get("title", "?"), frame % 2, variant]
	if not _cache.has(key):
		_cache[key] = _finish(_boss_image(d, frame % 2), variant)
	return _cache[key]


static func _boss_image(d: Dictionary, frame: int) -> Image:
	var r := float(d.get("radius", 14.0)) * 2.0 # painted at 2x pixel density
	var size := int(ceil(r * 3.0)) + 4
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c0 := Vector2(size / 2.0, size / 2.0 + r * 0.2)
	var base: Color = d.get("color", Color(0.8, 0.2, 0.3))
	var glow: Color = d.get("glow", Color(1, 0.9, 0.4))
	var light := base.lightened(0.28)
	var dark := base.darkened(0.32)
	var deep := base.darkened(0.55)
	var bone := base.lightened(0.55)
	var sy := 0.93 if frame == 1 else 1.0
	var sx := 1.04 if frame == 1 else 1.0
	var c := c0 + Vector2(0, r * (1.0 - sy))
	# Spikes (behind the body).
	var spikes := int(d.get("spikes", 0))
	for i in spikes:
		var a := TAU * i / maxf(1.0, spikes) + 0.4
		var dir := Vector2.RIGHT.rotated(a)
		var side := dir.orthogonal() * r * 0.24
		_fill_poly(img, PackedVector2Array([c + dir * r * 0.8 + side, c + dir * r * 1.42, c + dir * r * 0.8 - side]), deep, dark)
	# Horns.
	if d.get("horns", false):
		for sgn in [-1.0, 1.0]:
			_fill_poly(img, PackedVector2Array([
				c + Vector2(sgn * r * 0.45, -r * 0.55 * sy),
				c + Vector2(sgn * r * 1.12, -r * 1.45 * sy),
				c + Vector2(sgn * r * 0.1, -r * 0.82 * sy)]), bone, bone.darkened(0.25))
	# Body, shaded with a light from the top left, in 3 bands.
	var shape := String(d.get("body", "round"))
	var light_dir := Vector2(-0.55, -0.7).normalized()
	for y in size:
		for x in size:
			var p := (Vector2(x + 0.5, y + 0.5) - c) / Vector2(r * sx, r * sy)
			var dist := p.length()
			var ang := p.angle()
			var edge := 1.0
			if shape == "spiky":
				edge = 0.9 + 0.1 * signf(cos(ang * 8.0))
			elif shape == "blob":
				edge = 0.92 + 0.1 * sin(ang * 3.0 + frame * 1.2)
			if dist > edge:
				continue
			var shade := p.dot(light_dir)
			var col := base
			if shade > 0.42:
				col = light
			elif shade < -0.3 or dist > edge - 0.1:
				col = dark
			# Dithered edge between bands.
			if absf(shade - 0.42) < 0.06 and (x + y) % 2 == 0:
				col = base
			# Belly.
			var belly := (p - Vector2(0, 0.25)).length()
			if belly < 0.55:
				col = dark if belly > 0.45 or (belly > 0.4 and (x + y) % 2 == 0) else deep.lerp(dark, 0.4)
			img.set_pixel(x, y, col)
	# Mouth with teeth.
	var my := int(c.y + r * 0.28 * sy)
	var mw := int(r * 0.42)
	for x in range(int(c.x) - mw, int(c.x) + mw + 1):
		img.set_pixel(x, my, Color(0.08, 0.02, 0.05))
		img.set_pixel(x, my + 1, Color(0.08, 0.02, 0.05))
		if x % 2 == 0:
			img.set_pixel(x, my, Color(0.95, 0.92, 0.85))
	# Crown.
	if d.get("crown", false):
		var gold := Color(0.95, 0.8, 0.3)
		for i in 5:
			var x := -r * 0.6 + i * r * 0.3
			_fill_poly(img, PackedVector2Array([
				c + Vector2(x - r * 0.16, -r * 0.7 * sy),
				c + Vector2(x, -r * 1.28 * sy),
				c + Vector2(x + r * 0.16, -r * 0.7 * sy)]), gold, gold.darkened(0.3))
		for x in range(int(c.x - r * 0.72), int(c.x + r * 0.72)):
			for yy in 2:
				img.set_pixel(x, int(c.y - r * 0.72 * sy) + yy, gold.darkened(0.15))
	# Eyes: glowing blocks with a dark pupil.
	var eyes := int(d.get("eyes", 2))
	var es := maxi(2, int(r * 0.2))
	for i in eyes:
		var ex := int(c.x + (i - (eyes - 1) / 2.0) * r * 0.42) - es / 2
		var ey := int(c.y - r * 0.22 * sy) - es / 2
		for yy in es:
			for xx in es + 1:
				img.set_pixel(ex + xx, ey + yy, glow)
		img.set_pixel(ex + es / 2, ey + es / 2, Color(0.05, 0.02, 0.05))
		img.set_pixel(ex, ey, glow.lightened(0.6))
	_pad(img)
	return img


static func _fill_poly(img: Image, pts: PackedVector2Array, col: Color, shade: Color) -> void:
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	var mid := (pts[0] + pts[1] + pts[2]) / 3.0
	for y in range(maxi(0, int(rect.position.y)), mini(img.get_height(), int(rect.end.y) + 1)):
		for x in range(maxi(0, int(rect.position.x)), mini(img.get_width(), int(rect.end.x) + 1)):
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, pts):
				img.set_pixel(x, y, shade if p.x > mid.x + 0.5 else col)


## Clears the outer 1px border so the outline always fits.
static func _pad(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for x in w:
		img.set_pixel(x, 0, Color(0, 0, 0, 0))
		img.set_pixel(x, h - 1, Color(0, 0, 0, 0))
	for y in h:
		img.set_pixel(0, y, Color(0, 0, 0, 0))
		img.set_pixel(w - 1, y, Color(0, 0, 0, 0))


# ============================================================== weapons

## All weapons point right. "grip" is the x pixel the hand holds.
const WEAPON_PAL := {"O": Color(1.0, 0.55, 0.2), "V": Color(0.85, 0.5, 1.0), "U": Color(0.5, 0.8, 1.0), "R": Color(0.5, 0.2, 0.18), "w": Color(0.9, 0.88, 0.8)}
const WEAPONS := {
	"sword": {"grip": 1, "rows": [
		"...G..........",
		"bbbGWWWWWWWWW.",
		"bbbGMMMMMMMMMW",
		"...G..........",
	]},
	"greataxe": {"grip": 2, "rows": [
		"...........MMMM...",
		"..........MWMMMm..",
		"..........MWMMMm..",
		"bbbbbbbbbbbbbbbbb.",
		"..........MWMMMm..",
		"..........MWMMMm..",
		"...........MMMM...",
	]},
	"hammer": {"grip": 2, "rows": [
		"..........MMMM.",
		"..........MWMm.",
		"..........MWMm.",
		"bbbbbbbbbbMMMm.",
		"..........MMMm.",
		"..........MMMm.",
		"..........mmmm.",
	]},
	"spear": {"grip": 6, "rows": [
		"..................M...",
		"bbbbbbbbbbbbbbbbbbMWMM",
		"..................M...",
	]},
	"daggers": {"grip": 1, "rows": [
		"..G......",
		"bbGWMMMM.",
		"..GmmmM..",
	]},
	"rapier": {"grip": 1, "rows": [
		"..GG..............",
		"bbGGMMMMMMMMMMMMMW",
		"..GG..............",
	]},
	"scythe": {"grip": 3, "rows": [
		"bbbbbbbbbbbbbbbbM",
		"...........MWWWMm",
		".........MWWMM...",
		".......MWMM......",
		"......MM.........",
	]},
	"bow": {"grip": 0, "rows": [
		"wb...",
		"w.b..",
		"w..b.",
		"w..b.",
		"w...b",
		"w...b",
		"w...b",
		"w...b",
		"w...b",
		"w..b.",
		"w..b.",
		"w.b..",
		"wb...",
	]},
	"crossbow": {"grip": 2, "rows": [
		"........b...",
		"........b...",
		".........b..",
		".........b..",
		"bbbbbbbbbMMW",
		".........b..",
		".........b..",
		"........b...",
		"........b...",
	]},
	"knife": {"grip": 1, "rows": [
		"...G....",
		"bbbGMMMW",
		"...G....",
	]},
	"staff": {"grip": 4, "rows": [
		"..............GOO.",
		"bbbbbbbbbbbbbbOWOO",
		"..............GOO.",
	]},
	"wand": {"grip": 1, "rows": [
		"........V..",
		"bbbbbbbbVWV",
		"........V..",
	]},
	"grimoire": {"grip": 0, "rows": [
		"RRRRRR.",
		"RGGGGRw",
		"RGUUGRw",
		"RGUUGRw",
		"RGGGGRw",
		"RRRRRRw",
		".wwwwww",
	]},
}


## Weapon ids that share another weapon's sprite.
const WEAPON_SPRITE_ALIAS := {"knives": "knife"}


static func weapon(id: String) -> Texture2D:
	id = WEAPON_SPRITE_ALIAS.get(id, id)
	if not WEAPONS.has(id):
		id = "sword" # never crash on a weapon without its own sprite
	var key := "w/" + id
	if not _cache.has(key):
		var p := BASE_PAL.duplicate()
		p.merge(WEAPON_PAL, true)
		_cache[key] = _finish(_image(WEAPONS[id]["rows"], p), "")
	return _cache[key]


static func weapon_grip(id: String) -> int:
	id = WEAPON_SPRITE_ALIAS.get(id, id)
	return int(WEAPONS.get(id, WEAPONS["sword"])["grip"]) * 2 + 1 # doubled art, +1 for the outline border


# ============================================================== props, items, projectiles

const ITEMS := {
	"coin": {"pal": {"Y": Color(1.0, 0.82, 0.25), "y": Color(0.78, 0.55, 0.12), "W": Color(1, 1, 0.8)}, "frames": [
		["..YYY..", ".YWYYY.", "YWYYYyY", "YYYYYyY", "YYYYyyY", ".YyyyY.", "..YYY.."],
		["..YYY..", "..WYY..", "..WYy..", "..YYy..", "..YYy..", "..Yyy..", "..YYY.."],
		["...Y...", "...W...", "...Y...", "...Y...", "...y...", "...y...", "...Y..."],
		["..YYY..", "..YYW..", "..yYW..", "..yYY..", "..yYY..", "..yyY..", "..YYY.."],
	]},
	"heart": {"pal": {"R": Color(0.95, 0.25, 0.35), "r": Color(0.7, 0.12, 0.22), "W": Color(1, 0.8, 0.85)}, "frames": [
		[".RR.RR.", "RWRRRRr", "RRRRRRr", ".RRRRr.", "..RRr..", "...r..."],
		[".RRR.RRR.", "RWWRRRRRr", "RWRRRRRRr", "RRRRRRRRr", ".RRRRRRr.", "..RRRRr..", "...RRr..."],
	]},
	"torch": {"outline": false, "pal": {"Y": Color(1.0, 0.9, 0.45), "O": Color(1.0, 0.55, 0.15), "R": Color(0.85, 0.25, 0.1), "W": Color(1, 1, 0.85), "M": Color(0.45, 0.42, 0.4), "m": Color(0.25, 0.23, 0.22), "B": Color(0.35, 0.24, 0.14)}, "frames": [
		["..Y..", ".YYO.", "OYWYO", ".ORO.", "MmmmM", ".mBm.", "..B..", "..B.."],
		[".Y...", ".YY..", "OYWYO", ".ORO.", "MmmmM", ".mBm.", "..B..", "..B.."],
		["...Y.", "..YY.", "OYWYO", ".ORO.", "MmmmM", ".mBm.", "..B..", "..B.."],
	]},
	"chest": {"pal": {"B": Color(0.68, 0.45, 0.24), "b": Color(0.52, 0.32, 0.17), "g": Color(0.34, 0.2, 0.11), "G": Color(0.92, 0.75, 0.3), "Y": Color(1.0, 0.95, 0.6), "k": Color(0.08, 0.05, 0.04)}, "frames": [
		[
			"..BBBBBBBBBB..",
			".BbbbbbbbbbbB.",
			".bbbbbbbbbbbb.",
			".GGGGGYYGGGGG.",
			".bbbbbYYbbbbb.",
			".BbbbbbbbbbbB.",
			".bbbbbbbbbbbb.",
			".gbbbbbbbbbbg.",
			".gggggggggggg.",
		],
		[
			"..BBBBBBBBBB..",
			".BbbbbbbbbbbB.",
			".GGGGGGGGGGGG.",
			".kkkkkkkkkkkk.",
			".kkkkkkkkkkkk.",
			".BbbbbbbbbbbB.",
			".bbbbbbbbbbbb.",
			".gbbbbbbbbbbg.",
			".gggggggggggg.",
		],
	]},
	"shrine": {"pal": {"R": Color(1.0, 0.3, 0.38), "r": Color(0.65, 0.1, 0.18), "S": Color(0.55, 0.52, 0.6), "s": Color(0.36, 0.34, 0.42), "W": Color(1, 0.85, 0.85)}, "frames": [
		[
			".....RR.....",
			"....RWRr....",
			"....RRRr....",
			".....Rr.....",
			"............",
			"...SSSSSS...",
			"...SsSSsS...",
			"...SSSSSs...",
			"...SSRSSs...",
			"...SSSSSs...",
			"..SSSSSSSs..",
			".ssssssssss.",
		],
	]},
	"shrine_used": {"pal": {"R": Color(0.4, 0.4, 0.45), "r": Color(0.25, 0.25, 0.3), "S": Color(0.45, 0.43, 0.5), "s": Color(0.3, 0.29, 0.35), "W": Color(0.55, 0.55, 0.6)}, "frames": [
		[
			"............",
			"............",
			"............",
			"............",
			"............",
			"...SSSSSS...",
			"...SsSSsS...",
			"...SSSSSs...",
			"...SSRSSs...",
			"...SSSSSs...",
			"..SSSSSSSs..",
			".ssssssssss.",
		],
	]},
	"fountain": {"pal": {"S": Color(0.6, 0.6, 0.66), "s": Color(0.4, 0.4, 0.46), "L": Color(0.75, 0.75, 0.8), "w": Color(0.22, 0.45, 0.88), "W": Color(0.7, 0.9, 1.0)}, "frames": [
		[
			"....SSSSSSSSSSSS....",
			"..SSLLLLLLLLLLLLSS..",
			".SLWWwwwwwwwwwwWWLS.",
			"SLwwwwwwwwwwwwwwwwLS",
			"SLwwwwwwSSSSwwwwwwLs",
			"SLwWwwwwSLLSwwwwwwLs",
			"SLwwwwwwSSSSwwwWwwLs",
			"SLwwwwwwwwwwwwwwwwLs",
			".SLwwwwWwwwwwwwwwLs.",
			"..sSLLLLLLLLLLLLSs..",
			"....ssssssssssss....",
		],
		[
			"....SSSSSSSSSSSS....",
			"..SSLLLLLLLLLLLLSS..",
			".SLwwWWwwwwwwWWwwLS.",
			"SLwwwwwwwwwwwwwwwwLS",
			"SLwwwwwwSSSSwwwwWwLs",
			"SLwwwwwwSLLSwwwwwwLs",
			"SLwwWwwwSSSSwwwwwwLs",
			"SLwwwwwwwwwwwwwwwwLs",
			".SLwwwwwwwwwWwwwwLs.",
			"..sSLLLLLLLLLLLLSs..",
			"....ssssssssssss....",
		],
	]},
	"merchant": {"pal": {"G": Color(0.25, 0.5, 0.45), "g": Color(0.16, 0.34, 0.31), "W": Color(0.9, 0.9, 0.88)}, "frames": [
		[
			"....gg....",
			"...gGGg...",
			"..gGGGGg..",
			"..GSSSSG..",
			"..GESSEG..",
			"..GSSSSG..",
			"..GWWWWG..",
			".gGGWWGGg.",
			"gGGGGGGGGg",
			"GGGGGGGGGg",
			"gGGGGGGGGg",
		],
	]},
	"counter": {"pal": {"B": Color(0.62, 0.43, 0.25), "b": Color(0.47, 0.31, 0.18), "g": Color(0.3, 0.2, 0.11), "R": Color(0.95, 0.3, 0.35), "U": Color(0.4, 0.8, 1.0), "Y": Color(1.0, 0.85, 0.3), "c": Color(0.75, 0.6, 0.4)}, "frames": [
		[
			"..c.........c......c....",
			".RRR.......UUU....YYY...",
			".RWR.......UWU....YWY...",
			"BBBBBBBBBBBBBBBBBBBBBBBB",
			"bbbbbbbbbbbbbbbbbbbbbbbb",
			"bggbbbbbbggbbbbbbggbbbbg",
			"gggggggggggggggggggggggg",
		],
	]},
	"lantern": {"pal": {"m": Color(0.3, 0.28, 0.26), "Y": Color(1.0, 0.9, 0.5)}, "frames": [
		[".m.", "mYm", "mYm", ".m."],
	]},
	"bomb": {"pal": {"K": Color(0.16, 0.16, 0.2), "W": Color(0.55, 0.55, 0.62), "y": Color(0.6, 0.45, 0.3)}, "frames": [
		["..y..", ".KKK.", "KWKKK", "KKKKK", ".KKK."],
	]},
	# ---- monster parts (drops) and the extraction lift
	"part_gel": {"pal": {"G": Color(0.42, 0.85, 0.42), "g": Color(0.25, 0.55, 0.28), "W": Color(0.9, 1, 0.9)}, "frames": [
		["..GG...", ".GWGG..", "GWGGGg.", "GGGGGg.", ".gggg.."],
	]},
	"part_wing": {"pal": {"P": Color(0.68, 0.45, 0.9), "p": Color(0.42, 0.26, 0.6)}, "frames": [
		["p......", "pp.....", "pPp....", "pPPp...", "pPPPp..", ".pPPPp.", "..ppppp"],
	]},
	"part_silk": {"pal": {"W": Color(0.95, 0.95, 0.92), "w": Color(0.7, 0.7, 0.72)}, "frames": [
		[".WWWW.", "WwWwWW", "WWwWwW", "WwWwWW", ".wwww."],
	]},
	"part_bone": {"pal": {"W": Color(0.92, 0.9, 0.82), "w": Color(0.7, 0.68, 0.6)}, "frames": [
		["W.....W", "WWWWWWW", "w.....w"],
	]},
	"part_powder": {"pal": {"b": Color(0.5, 0.34, 0.2), "R": Color(0.95, 0.35, 0.2), "Y": Color(1, 0.85, 0.3)}, "frames": [
		["..Y..", ".bbb.", "bRRRb", "bRRRb", ".bbb."],
	]},
	"part_ecto": {"pal": {"W": Color(0.75, 0.88, 1.0), "L": Color(1, 1, 1)}, "frames": [
		["..W..", ".WWW.", "WWLWW", "WLWWW", ".WWW."],
	]},
	"part_ember": {"pal": {"F": Color(0.45, 0.95, 0.95), "L": Color(0.75, 1, 1), "W": Color(1, 1, 1)}, "frames": [
		["..F..", ".FF..", ".FLF.", "FLWLF", ".FFF."],
	]},
	"part_sigil": {"pal": {"R": Color(0.55, 0.2, 0.6), "G": Color(1.0, 0.45, 1.0)}, "frames": [
		[".RRR.", "RGRGR", "RRGRR", "RGRGR", ".RRR."],
	]},
	"part_horn": {"pal": {"H": Color(0.92, 0.88, 0.75), "h": Color(0.65, 0.6, 0.5)}, "frames": [
		["....H", "...HH", "..HH.", ".Hh..", "hh..."],
	]},
	"part_core": {"pal": {"S": Color(0.5, 0.47, 0.42), "F": Color(1.0, 0.6, 0.2), "Y": Color(1, 0.9, 0.5)}, "frames": [
		[".SSS.", "SSFSS", "SFYFS", "SSFSS", ".SSS."],
	]},
	"part_heart": {"pal": {"R": Color(0.7, 0.08, 0.2), "r": Color(0.45, 0.04, 0.12), "G": Color(1.0, 0.5, 0.4)}, "frames": [
		[".RR.RR.", "RGRRRRr", "RRRRRRr", ".RRRRr.", "..RRr..", "...r..."],
	]},
	"elevator": {"pal": {"m": Color(0.3, 0.3, 0.34), "M": Color(0.55, 0.56, 0.62), "c": Color(0.6, 0.55, 0.45), "G": Color(0.85, 0.7, 0.3), "k": Color(0.06, 0.06, 0.08), "g": Color(0.2, 0.2, 0.24), "P": Color(0.45, 0.45, 0.5), "Y": Color(0.95, 0.8, 0.2)}, "frames": [
		[
			"..mMMMMMMMMMMMMm..",
			"..mM....cc....Mm..",
			"..mM....cc....Mm..",
			"..mM....cc....Mm..",
			"..mM....cc....Mm..",
			"..mMGGGGGGGGGGMm..",
			"..mMkkkkkkkkkkMm..",
			"..mMkgkgkgkgkgMm..",
			"..mMkkkkkkkkkkMm..",
			"..mMkgkgkgkgkgMm..",
			"..mMkkkkkkkkkkMm..",
			"mmMMPPPPPPPPPPMMmm",
			"mPPPPPPPPPPPPPPPPm",
			"mYkYkYkYkYkYkYkYkm",
			"mmmmmmmmmmmmmmmmmm",
		],
	]},
	"sym_skull": {"pal": {"W": Color(0.93, 0.9, 0.82), "w": Color(0.7, 0.67, 0.6), "k": Color(0.12, 0.08, 0.1)}, "frames": [
		[".WWWWW.", "WWWWWWw", "WkkWkkw", "WkkWkkw", "WWWkWWw", ".WwWwW.", ".W.W.w."],
	]},
	"sym_gem": {"pal": {"C": Color(0.45, 0.9, 1.0), "c": Color(0.2, 0.5, 0.88), "W": Color(1, 1, 1)}, "frames": [
		["..ccc..", ".cCCCc.", "cCWCCCc", "cCCCCCc", ".cCCCc.", "..cCc..", "...c..."],
	]},
	"idol": {"pal": {"S": Color(0.55, 0.52, 0.6), "s": Color(0.36, 0.34, 0.42), "G": Color(0.88, 0.7, 0.28), "Y": Color(1.0, 0.92, 0.45), "R": Color(1.0, 0.3, 0.35), "k": Color(0.08, 0.06, 0.1), "W": Color(0.95, 0.92, 0.85)}, "frames": [
		[
			"....s.......s....",
			"....Ss.....sS....",
			".....SSSSSSSs....",
			"....SSRSSSRSSs...",
			"....SSSSkSSSSs...",
			"....SSskkksSSs...",
			"...GGGGGGGGGGGG.Y",
			"...GkkkkkkkkkkG.Y",
			"...GkWkkWkkkWkG.s",
			"...GkkkkkkkkkkG.s",
			"...GGGGGGGGGGGGss",
			"...SSSSSSSSSSSs..",
			"...SSsSSSSSSsSs..",
			"...SSSSSRSSSSSs..",
			"...SSSSSSSSSSSs..",
			"..SSSSSSSSSSSSSs.",
			".sssssssssssssss.",
		],
		[
			"....s.......s....",
			"....Ss.....sS....",
			".....SSSSSSSs....",
			"....SSYSSSYSSs...",
			"....SSSSkSSSSs...",
			"....SSskkksSSs...",
			"...GGGGGGGGGGGG.Y",
			"...GkkkkkkkkkkG.Y",
			"...GkWkkWkkkWkG.s",
			"...GkkkkkkkkkkG.s",
			"...GGGGGGGGGGGGss",
			"...SSSSSSSSSSSs..",
			"...SSsSSSSSSsSs..",
			"...SSSSSYSSSSSs..",
			"...SSSSSSSSSSSs..",
			"..SSSSSSSSSSSSSs.",
			".sssssssssssssss.",
		],
	]},
	"dust": {"outline": false, "pal": {"W": Color(0.92, 0.9, 0.88, 0.9), "w": Color(0.75, 0.73, 0.72, 0.75)}, "frames": [
		["..ww...", ".wWWw..", "wWWWWw."],
		["..w.w..", ".wWwWw.", "w.WWW.w"],
		[".w...w.", "w..w..w", ".w...w."],
		["w.....w", "...w...", "w.....w"],
		["w......", "......w", "...w..."],
	]},
	"arrow": {"pal": {"f": Color(0.95, 0.95, 0.95), "b": Color(0.7, 0.55, 0.35), "M": Color(0.85, 0.88, 0.95)}, "frames": [
		["f.......M..", ".fbbbbbbMMM", "f.......M.."],
	]},
	"knife": {"pal": {}, "frames": [
		["...G....", "bbbGMMMW", "...G...."],
	]},
}

## Stairs, steps getting darker the deeper they go.
const STAIRS := [
	"GGGGGGGGGGGGGGGG",
	"Gkkkkkkkkkkkkkkg",
	"G44444444444444g",
	"Gddddddddddddddg",
	"Gddddddddddddddg",
	"G33333333333333g",
	"Gccccccccccccccg",
	"Gccccccccccccccg",
	"G22222222222222g",
	"Gbbbbbbbbbbbbbbg",
	"Gbbbbbbbbbbbbbbg",
	"G11111111111111g",
	"Gaaaaaaaaaaaaaag",
	"Gaaaaaaaaaaaaaag",
	"Gaaaaaaaaaaaaaag",
	"gggggggggggggggg",
]


static func item(name: String, frame := 0, variant := "") -> Texture2D:
	var def: Dictionary = ITEMS[name]
	var frames: Array = def["frames"]
	var idx := frame % frames.size()
	var key := "i/%s/%d/%s" % [name, idx, variant]
	if not _cache.has(key):
		var p := BASE_PAL.duplicate()
		p.merge(def["pal"], true)
		var img := _image(frames[idx], p)
		if def.get("outline", true):
			_cache[key] = _finish(img, variant)
		else:
			_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


static func item_frames(name: String) -> int:
	return (ITEMS[name]["frames"] as Array).size()


static func stairs(plunge: bool) -> Texture2D:
	var key := "stairs/%s" % plunge
	if not _cache.has(key):
		var rim := Color(0.62, 0.42, 0.68) if plunge else Color(0.55, 0.52, 0.5)
		var step := Color(0.6, 0.38, 0.65) if plunge else Color(0.62, 0.58, 0.54)
		var p := {"G": rim, "g": rim.darkened(0.4), "k": Color(0.02, 0.01, 0.03)}
		for i in 4:
			p[str(i + 1)] = step.darkened(i * 0.2)
			p["abcd"[i]] = step.darkened(0.35 + i * 0.18)
		_cache[key] = _finish(_image(STAIRS, p), "")
	return _cache[key]


## A glowing orb (magic bolts, enemy bullets, spirits), tinted to `col`.
static func orb(col: Color) -> Texture2D:
	var key := "orb/" + col.to_html(false)
	if not _cache.has(key):
		var p := {"c": col.darkened(0.15), "L": col.lightened(0.4), "W": Color(1, 1, 1)}
		var img := _image([".ccc.", "cLWLc", "cWWWc", "cLWLc", ".ccc."], p)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


# ============================================================== dungeon tiles

## Builds this floor's tile set in its colours at 2x pixel density (32x32 per 16-unit tile):
## 8 floor variants, 4 wall-face variants, 3 wall-top variants and a shadow strip.
static func tileset(biome: Dictionary, tile: int) -> Dictionary:
	var t := tile * 2
	var floor_c: Color = biome["floor"]
	var wall_c: Color = biome["wall"]
	var face_c: Color = biome["wall_face"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(floor_c.to_html())
	var floors: Array[Image] = []
	for v in 8:
		floors.append(_floor_tile(floor_c, v, rng, t))
	var faces: Array[Image] = []
	for v in 4:
		faces.append(_face_tile(wall_c, face_c, v, rng, t))
	var tops: Array[Image] = []
	for v in 3:
		tops.append(_top_tile(wall_c, rng, t))
	var shadow := Image.create(t, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in t:
			var a := 0.5 * (1.0 - y / 10.0)
			if y > 4 and (x + y) % 2 == 1:
				a *= 0.5
			shadow.set_pixel(x, y, Color(0, 0, 0, a))
	return {"floor": floors, "face": faces, "top": tops, "shadow": shadow, "size": t}


## Flagstones: 2x2 bevelled slabs per tile (offset rows), speckled, with optional details.
static func _floor_tile(base: Color, variant: int, rng: RandomNumberGenerator, t: int) -> Image:
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	var grout := base.darkened(0.42)
	var half := t / 2
	for row in 2:
		var off := 0 if row == 0 else half / 2
		for col in range(-1, 3):
			var x0 := col * half + off
			var slab := base.lightened(rng.randf_range(-0.05, 0.07)) if rng.randf() < 0.7 else base.darkened(rng.randf_range(0.03, 0.12))
			for y in range(row * half, row * half + half):
				for x in range(x0, x0 + half):
					if x < 0 or x >= t:
						continue
					var lx := x - x0
					var ly := y - row * half
					var c := slab
					if lx == 0 or ly == 0:
						c = grout
					elif ly == 1 or lx == 1:
						c = slab.lightened(0.1)
					elif ly == 2 and lx > 2 and lx < half - 3:
						c = slab.lightened(0.04)
					elif ly == half - 1 or lx == half - 1:
						c = slab.darkened(0.14)
					elif ly == half - 2 or lx == half - 2:
						c = slab.darkened(0.06)
					else:
						var n := rng.randf()
						if n < 0.05:
							c = slab.lightened(0.09)
						elif n < 0.11:
							c = slab.darkened(0.08)
					img.set_pixel(x, y, c)
	match variant:
		1: # crack
			var x := rng.randi_range(6, t - 8)
			var y0 := rng.randi_range(3, 9)
			for y in range(y0, rng.randi_range(t - 10, t - 3)):
				img.set_pixel(clampi(x, 0, t - 1), y, grout.darkened(0.25))
				img.set_pixel(clampi(x + 1, 0, t - 1), y, base.darkened(0.2))
				if rng.randf() < 0.35:
					x += 1 if rng.randf() < 0.5 else -1
		2: # pebbles
			for i in 4:
				var p := Vector2i(rng.randi_range(3, t - 5), rng.randi_range(3, t - 5))
				var pc := base.lightened(rng.randf_range(0.15, 0.3))
				img.set_pixel(p.x, p.y, pc.lightened(0.15))
				img.set_pixel(p.x + 1, p.y, pc)
				img.set_pixel(p.x, p.y + 1, pc)
				img.set_pixel(p.x + 1, p.y + 1, pc.darkened(0.2))
				img.set_pixel(p.x, p.y + 2, grout)
				img.set_pixel(p.x + 1, p.y + 2, grout)
		3: # moss patch
			var moss := Color.from_hsv(0.28, 0.45, base.v + 0.14)
			var p := Vector2i(rng.randi_range(4, t - 10), rng.randi_range(4, t - 10))
			for i in 30:
				var q := Vector2i(clampi(p.x + rng.randi_range(-4, 4), 0, t - 1), clampi(p.y + rng.randi_range(-2, 4), 0, t - 1))
				img.set_pixel(q.x, q.y, moss.darkened(rng.randf() * 0.3) if rng.randf() < 0.8 else moss.lightened(0.15))
		4: # little bone
			var p := Vector2i(rng.randi_range(6, t - 16), rng.randi_range(8, t - 10))
			var bone := Color(0.85, 0.83, 0.75)
			for i in 9:
				img.set_pixel(p.x + i, p.y, bone)
				img.set_pixel(p.x + i, p.y + 1, bone.darkened(0.12))
				img.set_pixel(p.x + i, p.y + 2, grout)
			for e in [Vector2i(-1, -1), Vector2i(-2, -1), Vector2i(-1, 2), Vector2i(-2, 2), Vector2i(9, -1), Vector2i(10, -1), Vector2i(9, 2), Vector2i(10, 2)]:
				img.set_pixel(p.x + e.x, p.y + e.y, bone)
		5: # puddle stain
			var p := Vector2(rng.randi_range(8, t - 8), rng.randi_range(8, t - 8))
			for y in t:
				for x in t:
					var d := Vector2((x - p.x) / 6.0, (y - p.y) / 3.5).length()
					if d < 1.0:
						img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.18 if d > 0.6 else 0.28))
	return img


## Brick wall face with a stone lip on top, mortar, highlights and the odd damage.
static func _face_tile(top_c: Color, face_c: Color, variant: int, rng: RandomNumberGenerator, t: int) -> Image:
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	var mortar := face_c.darkened(0.4)
	var lip := 8
	for y in lip:
		for x in t:
			var c := top_c
			if y == 0:
				c = top_c.lightened(0.18)
			elif y == 1:
				c = top_c.lightened(0.08)
			elif y >= lip - 2:
				c = top_c.darkened(0.3 if y == lip - 1 else 0.15)
			elif rng.randf() < 0.1:
				c = top_c.darkened(0.08)
			img.set_pixel(x, y, c)
	var bh := 6
	var bw := 12
	var row := 0
	var y0 := lip
	while y0 < t:
		var x0 := -(0 if row % 2 == 0 else bw / 2)
		while x0 < t:
			var bc := face_c.lightened(rng.randf_range(-0.05, 0.08))
			if variant == 3 and row == 1 and x0 > 0 and x0 < t / 2:
				bc = face_c.darkened(0.3)
			for y in range(y0, mini(y0 + bh, t)):
				for x in range(maxi(x0, 0), mini(x0 + bw, t)):
					var c := bc
					var lx := x - x0
					var ly := y - y0
					if ly == bh - 1 or lx == 0:
						c = mortar
					elif ly == 0:
						c = bc.lightened(0.12)
					elif ly == bh - 2 or lx == bw - 1:
						c = bc.darkened(0.12)
					elif rng.randf() < 0.07:
						c = bc.darkened(0.07)
					img.set_pixel(x, y, c)
			x0 += bw
		y0 += bh
		row += 1
	if variant == 1: # crack
		var x := rng.randi_range(8, t - 9)
		for y in range(lip + 3, t - 3):
			img.set_pixel(x, y, mortar.darkened(0.35))
			if rng.randf() < 0.3:
				x = clampi(x + (1 if rng.randf() < 0.5 else -1), 1, t - 2)
	elif variant == 2: # moss dripping from the lip
		var moss := Color.from_hsv(0.3, 0.4, face_c.v + 0.16)
		for x in t:
			if rng.randf() < 0.5:
				for y in range(lip, lip + rng.randi_range(1, 7)):
					img.set_pixel(x, y, moss.darkened(rng.randf() * 0.3))
	for x in t:
		img.set_pixel(x, t - 1, face_c.darkened(0.55))
		img.set_pixel(x, t - 2, face_c.darkened(0.3))
	return img


static func _top_tile(top_c: Color, rng: RandomNumberGenerator, t: int) -> Image:
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	var inner := top_c.darkened(0.22)
	for y in t:
		for x in t:
			var c := inner
			var n := rng.randf()
			if n < 0.08:
				c = inner.darkened(0.12)
			elif n < 0.13:
				c = inner.lightened(0.07)
			# Faint big cobbles.
			if (x + (y / 8) * 4) % 8 == 0 and y % 8 != 0:
				c = c.darkened(0.06)
			if y % 8 == 0:
				c = c.darkened(0.06)
			img.set_pixel(x, y, c)
	return img


# ============================================================== building blocks

## Stacks a body on top of legs. The body can be pushed down by `bob` pixels (it covers the
## top of the legs), which is what makes the walk cycle bounce.
static func _compose(body: Array, legs: Array, bob: int) -> Array:
	var w := 0
	for r in body + legs:
		w = maxi(w, (r as String).length())
	var h := body.size() + legs.size()
	var grid: Array = []
	for i in h:
		grid.append(".".repeat(w))
	_paste(grid, legs, body.size())
	_paste(grid, body, bob)
	return grid


static func _paste(grid: Array, rows: Array, y0: int) -> void:
	for i in rows.size():
		var y := y0 + i
		if y < 0 or y >= grid.size():
			continue
		var line: String = grid[y]
		var src: String = rows[i]
		for x in mini(src.length(), line.length()):
			var ch := src[x]
			if ch != "." and ch != " ":
				line = line.substr(0, x) + ch + line.substr(x + 1)
		grid[y] = line


## Frames 0-3 are the walk cycle, 4-5 are the idle "breathing" frames.
static func _walker(body: Array, legs: Dictionary, idx: int) -> Array:
	if idx < 4:
		var step: Array = legs["seq"][idx]
		return _compose(body, legs[step[0]], int(step[1]))
	return _compose(body, legs["idle"], idx - 4)


## Text grid -> image. The grid is doubled with Scale2x (smooth pixel-art upscaling, rounds off
## diagonals) to match the game's 2x pixel density, with a 1px empty border for the outline.
static func _image(rows: Array, pal: Dictionary) -> Image:
	var w := 0
	for r in rows:
		w = maxi(w, (r as String).length())
	var h := rows.size()
	var small := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			if ch == "." or ch == " ":
				continue
			if pal.has(ch):
				small.set_pixel(x, y, pal[ch])
	var img := Image.create(w * 2 + 2, h * 2 + 2, false, Image.FORMAT_RGBA8)
	var clear := Color(0, 0, 0, 0)
	for y in h:
		for x in w:
			var p := small.get_pixel(x, y)
			var a := small.get_pixel(x, y - 1) if y > 0 else clear
			var b := small.get_pixel(x + 1, y) if x < w - 1 else clear
			var c := small.get_pixel(x - 1, y) if x > 0 else clear
			var d := small.get_pixel(x, y + 1) if y < h - 1 else clear
			var e0 := a if c == a and c != d and a != b else p
			var e1 := b if a == b and a != c and b != d else p
			var e2 := c if d == c and d != b and c != a else p
			var e3 := d if b == d and b != a and d != c else p
			img.set_pixel(x * 2 + 1, y * 2 + 1, e0)
			img.set_pixel(x * 2 + 2, y * 2 + 1, e1)
			img.set_pixel(x * 2 + 1, y * 2 + 2, e2)
			img.set_pixel(x * 2 + 2, y * 2 + 2, e3)
	return img


## Adds the outline and turns the image into a texture.
## variant: "" normal, "elite" gold outline, "white" hit flash (all white).
static func _finish(img: Image, variant: String) -> ImageTexture:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	# Soft rim light: pixels on the top-left edge of the shape get lighter, bottom-right
	# edge pixels darker. Gives every sprite some volume without hand-shading it all.
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var up := y == 0 or src.get_pixel(x, y - 1).a <= 0.0
			var left := x == 0 or src.get_pixel(x - 1, y).a <= 0.0
			var down := y == h - 1 or src.get_pixel(x, y + 1).a <= 0.0
			var right := x == w - 1 or src.get_pixel(x + 1, y).a <= 0.0
			if up or left:
				img.set_pixel(x, y, c.lightened(0.14))
			elif down or right:
				img.set_pixel(x, y, c.darkened(0.16))
	# Outline in a dark shade of the colour it touches (smoother than flat black),
	# gold for elites.
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			var touch := Color(0, 0, 0, 0)
			for o in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var n := src.get_pixel(nx, ny)
					if n.a > 0.5 and (touch.a == 0.0 or n.get_luminance() < touch.get_luminance()):
						touch = n
			if touch.a > 0.0:
				var col := ELITE_OUTLINE
				if variant != "elite":
					col = OUTLINE.lerp(touch.darkened(0.55), 0.45)
					col.a = 1.0
				img.set_pixel(x, y, col)
	if variant == "white":
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, Color(1, 1, 1, img.get_pixel(x, y).a))
	return ImageTexture.create_from_image(img)


## World units per art pixel: all art has twice the pixels and is drawn at half size.
const PX := 0.5


## Draws a texture centred horizontally with its bottom edge at `feet` (local space).
## Flips horizontally when `flip` is true. Snapped to the art-pixel grid.
## `scale` is world units per art pixel (menus pass a bigger one).
static func draw_at(ci: CanvasItem, tex: Texture2D, feet: Vector2, flip := false, mod := Color.WHITE, scale := PX) -> void:
	var size := tex.get_size() * scale
	var pos := Vector2(feet.x - size.x / 2.0, feet.y - size.y)
	pos = (pos / scale).round() * scale
	ci.draw_set_transform(pos + Vector2(size.x if flip else 0.0, 0.0), 0.0, Vector2(-scale if flip else scale, scale))
	ci.draw_texture(tex, Vector2.ZERO, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws a texture centred on `center`, optionally rotated.
static func draw_centered(ci: CanvasItem, tex: Texture2D, center: Vector2, mod := Color.WHITE, angle := 0.0, scale := PX) -> void:
	ci.draw_set_transform(center, angle, Vector2(scale, scale))
	ci.draw_texture(tex, -(tex.get_size() / 2.0).round(), mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws a weapon (or any right-pointing sprite) from `origin`, rotated to `dir`.
## `grip` is the art-pixel column that sits on `origin`. Mirrored vertically when pointing
## left so it never ends up upside down.
static func draw_rotated(ci: CanvasItem, tex: Texture2D, origin: Vector2, dir: Vector2, grip: float, mod := Color.WHITE, flip_y := false, scale := PX) -> void:
	var fy := -1.0 if (dir.x < 0.0) != flip_y else 1.0
	ci.draw_set_transform(origin, dir.angle(), Vector2(scale, fy * scale))
	ci.draw_texture(tex, Vector2(-grip, -round(tex.get_height() / 2.0)), mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
