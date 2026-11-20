# GHOSTBOUND (formerly Depthbound) — design brainstorm

> Working title. Other ideas: *Deeper*, *Below*, *The Long Descent*, *Hollowdeep*, *Stairfall*, *Lantern & Bone*.

A top-down action roguelike. You go down a procedurally generated dungeon one floor at a time.
Every floor is harder, every staircase gives you a power-up, and when you die the run is over.
It is built in Godot 4 and plays on PC (keyboard, mouse or gamepad) and on mobile (touch).

---

## Core pillars

1. **One more floor.** Floors are short (1–3 minutes). Taking the stairs feels great and is always tempting.
2. **Readable chaos.** Simple shapes, clear warning signs before attacks, one-thumb friendly.
3. **Builds, not grinding.** Power comes from combining upgrades during the run. Meta progression is light.
4. **Same game on both platforms.** Every control scheme works with auto-aim. The mouse just adds precision.

---

## The core loop

```
Enter floor → explore rooms → fight → grab loot → find stairs
      ↑                                              ↓
   new biome every 5 floors  ←  boss  ←  pick 1 of 3 upgrades
```

---

## Brainstorm: the "going deeper" hook

These ideas make descending feel like a choice, not just a door.

- **The lantern.** Your light radius slowly shrinks the longer you stay on a floor. Oil drops refill it. This pushes you down and creates tension without a hard timer.
- **Risky stairs.** Some floors have two staircases. One is normal; the other is a cursed "plunge" that skips a floor, gives a better reward, and adds a curse.
- **Depth pressure.** Every 10 floors, "Depth Marks" stack (enemies +10% speed, elites more common). Show them as a badge counter.
- **Echoes of past runs.** Your previous character's ghost appears at the floor where they died. Beat it to get some of their gold back.
- **Collapse.** After clearing a floor, the ceiling starts falling (danger zones on the ground) to push you toward the stairs.
- **Floor modifiers** (rolled per floor, shown on the banner): *Flooded* (slower movement, lightning upgrades get stronger), *Darkness*, *Infested* (2× enemies, 2× gold), *Treasure Vault*, *Silent* (no music, enemies don't notice you as easily).

## Brainstorm: build and upgrade ideas

- **Stat blessings** (implemented now): damage, fire rate, speed, max HP, multishot, pierce, range, luck.
- **Relics with synergies:** *Ember Core* (bolts ignite) + *Oil Flask* (burning ground) = fire build. *Frost Shard* (slow) + *Shatter* (frozen enemies explode).
- **Elemental bolt types:** fire (DoT), frost (slow), storm (chains between enemies), void (pulls enemies in).
- **Active ability slot:** dash, shield bash, bomb, or blink. Mobile gets a second button for it.
- **Cursed upgrades:** big power with a downside, e.g. "+2 damage, but hearts heal half as much".
- **Shrines:** spend HP or gold for a random blessing. Gambling shrines. A "reroll the upgrade choice" altar.

## Brainstorm: enemies

| Enemy | Behavior | Status |
|---|---|---|
| Slime | Slow chaser | ✅ in |
| Bat | Fast, wobbly path | ✅ in |
| Skeleton archer | Keeps distance, shoots when it can see you | ✅ in |
| Brute | Winds up, then charges in a line | ✅ in |
| Mimic | Looks like a chest | idea |
| Necromancer | Raises dead slimes, flees | idea |
| Spore pod | Stationary, explodes into a poison cloud | idea |
| Eel (Drowned Halls) | Hides under water tiles | idea |
| Elites | Any enemy + a modifier (shielded, splitting, fast, vampiric) | idea |

**Bosses (every 5 floors):** *The Warden* (radial bullet bursts, gets angrier at half HP, ✅ in), *Mother Spore*, *The Drowned King*, *Magma Wyrm*, *The Hollow* (copies your upgrades).

## Brainstorm: biomes (change every 5 floors)

1. **Upper Crypt.** Gray stone, slimes and bats. ✅
2. **Fungal Caverns.** Glowing mushrooms that are light sources and explode. ✅ (colors)
3. **Drowned Halls.** Water tiles slow you down, eels. ✅ (colors)
4. **Molten Depths.** Lava cracks, fire enemies. ✅ (colors)
5. **The Abyss.** Shifting walls, void enemies, endless scaling. ✅ (colors)

## Brainstorm: meta progression (between runs)

- **The Camp** (hub). Spend "Soul Shards" (kept after death) on unlocks only, not raw stats: new starting classes, new relics added to the pool, new biomes.
- **Classes:** *Wanderer* (balanced bolts), *Knight* (melee arc, more HP), *Rogue* (dash and crits), *Alchemist* (lobbed potions).
- **Shortcuts:** after beating a boss you can start future runs at that biome (fewer rewards).
- **Daily seed** run with a leaderboard (easy, because the dungeon is seeded).

## Mobile + PC controls

Combat follows Noctis: weapons run on **charges** (3 at the start, used one per attack, refilled one at a time). Every attack is either **tap = auto-aim** or **hold/drag = aim preview, release = strike**. The **dodge** is a short dash with i-frames and a cooldown.

| Action | PC | Gamepad | Mobile |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Floating joystick (left half of screen) |
| Attack (auto-aim) | Space / J | X / RB | Tap the attack stick (right half) |
| Attack (aimed) | Hold left mouse to aim, release to strike | Push right stick, let go to strike | Drag the attack stick, release to strike (drag back to the centre to cancel) |
| Dodge | Shift / right mouse | A / LB | Dodge button |
| Pause | Esc / P | Start | ❚❚ button (also pauses when the app goes to the background) |
| Pick upgrade | Click / 1-2-3 | D-pad + A | Tap |

Weapons (found as upgrade choices): Sword (110° slash), Twin Daggers (fast short slashes), Spear (long thrust), Hammer (slam + stun), Scythe (360° spin), Bow (piercing arrow).

## Art and audio direction

- **Pixel art (in now):** every character, enemy, weapon, prop, pickup, projectile and tile is pixel art in `scripts/sprites.gd`. Sprites are text grids (one character per pixel), so you can edit them right in the script. They get an automatic dark outline (gold for elites, white flash on hit).
  - Player: 4 classes × 3 facings (front / side / back), each with a 4-frame walk cycle and 2 idle "breathing" frames. The held weapon is a rotating sprite with swing, thrust and pull animations.
  - Enemies: walk cycles (skeleton, bomber, cultist, brute, golem), squash-and-stretch slimes, flapping bats, scuttling spiders, wavy ghosts, flickering wisps. They face the direction they move.
  - Bosses: painted pixel by pixel from their random look data (body shape, horns, crown, spikes, eyes, mouth), with a 2-frame breathing animation.
  - Dungeon: flagstone floors with cracks, moss, pebbles and bones; brick wall faces with mossy lips; recoloured for each floor.
  - Preview all sprites: `godot --headless -s res://tools/sprite_sheet.gd -- sheet.png`
- Juice to add: hit-stop, particles, damage numbers, stairs "whoosh" transition, footstep dust.
- Audio: one ambient track per biome, deeper and more distorted as you go down.

---

## What's in now (v0.2)

- **Home screen** with 3 save slots: Continue / New / Delete (asks "Sure?"). Autosaves at the start of every floor, plus Save & quit in the pause menu. Death ends the run, but the slot remembers your best depth.
- **4 classes**, each with its own weapon pool:
  - Fighter (melee, strong): Sword, Greataxe, Hammer, Spear
  - Rogue (melee, fast): Twin Daggers, Rapier, Scythe
  - Archer (ranged, fast): Bow, Crossbow, Throwing Knives
  - Mage (ranged, strong): Fire Staff (delayed blast), Storm Grimoire (chain lightning), Arcane Wand
- **Bigger floors** that keep growing, plus a fog-of-war **minimap**.
- **Enemies:** slime (splits into slimelets), bat, spider (lunges), skeleton archer, bomber (explodes), ghost (passes through walls), wisp (burst shots), cultist (summons bats), brute (charges), golem (rock spread). Random **elites** (gold ring, 2.5x HP, 3x gold).
- **Every floor is randomly generated** (look, name, size, rooms, enemy mix). Difficulty comes only from depth: tougher enemy types unlock deeper (spider 2, skeleton 3, bomber 4, wisp 5, brute 6, ghost 7, cultist 9, golem 11), and enemy health, damage, speed, numbers and elite chance keep scaling. **Floors are endless.**
- **A randomly generated boss every 10th floor:** random name ("Vorrak, the Pale Warden"), body, colours, horns/crown/spikes/eyes, minion type, and attack patterns picked from radial, spiral, fan, mines, slam, charge, summon and teleport. Bosses get 2 patterns at floor 10, plus 1 more every 20 floors.
- **Rare floor events** (30% of floors, always a trader after a boss): Wandering Trader (shop), Blood Shrine (2 HP for a blessing), Treasure Chest, Healing Fountain.

## What's in now (v0.3)

- **Devour bosses (the core hook):** each boss leaves 1 random power from itself. **Actives** come from the boss's own attacks (Nova, Spiral Storm, Barrage, Minefield, Quake, Rampage, Spirit Swarm, Blink), use keys Q/E/R/F, gamepad Y/B/LT/RT, or the 4 touch buttons around the attack button, and have cooldowns. **Passives** are always on (Thorns, Bloodthirst, Bloodlust, Echo, Spiked Shell, Aura of Dread, Second Wind, Overcharge, Volatile Death, Orbiting Shards). 4 slots each; when they're full you choose what to replace. Active damage scales with the depth of the boss you took it from.
- **Soul Shards and the Soul Altar:** earned when a run ends. Spend them on locked weapons, Deep Pockets, Haggler, Fortune's Eye, Heirloom, Soul Anchor (one revive), and depth 11/21 shortcuts.
- **Sound, music and lighting:** all sound effects and two music loops are generated in code. There's a dim world with light around the player, flickering wall torches, and glowing stairs and events.
- **Settings:** volumes, touch button size, swap touch sides, screen shake, FPS counter, tutorial hints.
- **Daily Run:** everyone gets the same floors today (seeded), with your best depth for the day.
- **Tutorial:** hints on the first run (move, attack, aim, charges, dodge, stairs, bosses).
- **Cursed plunge stairs:** sometimes a second staircase gives +2 depth and a pick of 4 blessings, but adds a run-long curse.
- **Floor modifiers:** Darkness, Flooded, Infested, Silent, Unstable.
- **Elite affixes:** Shielded, Splitting, Vampiric, Swift, Explosive, Toxic (2 affixes past depth 25).

## What's in now (v0.4)

- **Cleaner pixel art:** slimmer 10-px-wide heroes (plume on the fighter, scarf on the rogue, beard on the mage). Outlines are a dark shade of the colour they touch, and all sprites get automatic rim light and shade.
- **Monster parts:** every monster type drops its own part. Normal foes have a 30% chance; elites always drop 2. Bosses drop 2 Boss Hearts plus 3 parts from the floor's monsters. Parts go into your run **bag** (shown as "Parts" in the HUD).
- **Extraction Lift every 5th floor:** ride it to end the run safely, keep every part in your bag and get +25% Soul Shards. On boss floors it is locked until the boss dies. If you die, the bag is lost.
- **Workshop (main menu):** spend parts on permanent upgrades. Each can be crafted a few times, and the cost rises per level.
  - Bone Charm: +1 HP
  - Silk Wraps: +5% speed
  - Ember Whetstone: +8% damage
  - Ecto Lens: +4% crit
  - Horn Talisman: -10% dodge cooldown
  - Powder Pouch: +1 charge
  - Sigil of Greed: +20% gold
  - Lucky Charm: more hearts
  - Scavenger's Pack: more part drops
  - Heart Forge: start with a random boss power

  Parts and recipes are defined in `scripts/materials.gd`.

## What's in now (v0.5)

- **New chibi heroes** (`scripts/hero_art.gd`): side view (mirrored for left) with a big round head, big eye, small body and scarf.
  - Built from layers: body frame, head, hairstyle, class headgear and eyes.
  - Animations: idle (4 frames), walk (6), attack (4), hurt (white flash + recoil), dodge (crouch, dash, land), death (stagger, crumple, fall over).
  - Pixel dust puffs come off the feet when walking and dodging.
- **Character creator** after picking a class:
  - Name
  - 8 hairstyles: short, spiky, long, ponytail, bob, buzz, mohawk, bald
  - 9 hair colours, 6 skin tones, 6 eye colours, 8 scarf colours
  - 8 outfit colours (or the class colours)
  - Class headgear on/off: helmet, hood, cap or hat

  It has a Randomize button and a live animated preview, and remembers your last look for each class. The look is saved with the run, and save slots show "Name the Class".

## What's in now (v0.6)

- **2x pixel density everywhere:** all art has twice the pixels and is drawn at half size (`Sprites.PX = 0.5`), so things are the same size in the world with twice the detail.
  - Heroes are painted at 40x54 from shapes (round head, big eye, hair, gear, scarf, limbs) with 3-tone shading. The walk cycle has 8 frames.
  - Dungeon tiles are generated at 32x32 per tile (bevelled flagstones, finer bricks, stains). Bosses are painted at 2x.
  - Enemies, items and weapons are their old grids upscaled with Scale2x, which rounds off diagonals.

## Roadmap

**v0.1, prototype (done):** procedural floors, descending, 4 enemies + boss, auto-aim bolts, pickups, upgrades, HUD, touch controls, pause, game over.

**v0.2:** sprites + TileMapLayer, sounds, a dash, minimap / fog of war, chests and the lantern mechanic.

**v0.3:** relics and synergies, elites, shops/shrines, floor modifiers, save settings.

**v0.4:** meta hub, classes, Android/iOS exports, web build on itch.io.

### v0.7 — Motion blur removed
- The hero is the layered, high-res procedural chibi sprite (HeroArt), with per-class gear and the full character creator.
- Removed effects that smeared moving sprites: dodge afterimages, dodge puffs and projectile streaks.
- Enabled `rendering/2d/snap/snap_2d_transforms_to_pixel` so sprites stay crisp while moving.

### v0.8 — Gear drops, more stair upgrades, a new walk cycle
- **Walk cycle**
  - The whole body moves: it rises on the passing step and sinks on contact (4 px), and leans into the walk.
  - The head bobs a beat behind the body, and the arms swing against the legs.
  - Poses have head offsets (`hx`, `hy`) separate from the body offsets (`bx`, `by`).
- **Gear drops** (scripts/gear.gd)
  - Drop chances: 3.5% from normal foes, 30% from elites, and every boss drops one (always rare).
  - 6 helmets/hats, 6 armours, and weapons from the class pool with a random affix.
  - Each piece changes the hero's look (HeroArt `eq_head` / `eq_body`) and carries one boon.
  - Rare pieces have their boon ×1.6.
  - Walking over a piece equips it if that slot is empty. Otherwise a dialog offers Equip or Salvage for gold.
  - Boons are applied on equip and undone on unequip. `Player.equipment` is saved with the run.
- **Stairs**
  - Stairs no longer offer weapon swaps. Weapons now come from gear drops and the trader.
  - The upgrade pool grew from 9 to 22: Glass Cannon, Iron Skin, Gold Rush, Leech, Brutal Crits, Magnet, Titan, Frenzy, Focus, Treasure Hunter, Campfire, Executioner, Acrobat.

### v0.9 — Ghost hero, Cursed Idol, drag scrolling, smooth motion
- **The hero is a hovering cartoon ghost**
  - Look: a dome head, a sheet with a wavy hem, two big eyes, a little "oo" mouth and nub arms.
  - No legs. It floats a few pixels above a soft shadow.
  - Idle: bobs up and down.
  - Moving: glides, leaning forward with the sheet streaming and rippling behind.
  - Dodge: stretches into a whoosh.
  - Creator: "Skin" became "Ghost colour". Hair, headgear, scarf (wrapped round the middle) and armour drawn on top still work. Footstep dust is gone.
  - The weapon hand follows the hover bob (`HeroArt.body_offset`).
- **Cursed Idol**: a new floor event (weight 3) with slot-machine reels (scripts/slot_reels.gd) in the HUD dialog.
  - Price: (15 + 3×depth) gold, ×1.5 per pull on the same idol.
  - Three of a kind:
    - Coins: 6× the stake.
    - Hearts: +1 max HP and a full heal.
    - Swords: a rare gear drop.
    - Gems: 2 upgrades.
  - Two of a kind:
    - Coins: 2× the stake.
    - Hearts: heal 2.
    - Swords: a gear drop.
    - Gems: 1 upgrade.
  - Two skulls: −1 HP.
  - Three skulls: a curse, or the idol spits out an ambush and breaks.
  - The odds are in `main.SLOT_ODDS`.
- **Drag scrolling**: the Workshop and Soul Altar scroll by dragging anywhere on the screen, with momentum (scripts/drag_scroll.gd).
  - Taps still press buttons.
  - A drag cancels the button press.
- **Motion blur fix**
  - The likely cause: the player and monsters moved only on 60 Hz physics ticks while the camera eased in between, which gives judder and double images on fast screens.
  - Physics interpolation is now on, and camera smoothing is off. The camera sticks to the player.
  - Spawns and teleports call `reset_physics_interpolation()`.

### v0.9.1 — One-tailed ghost, ghost-only creator
- **Ghost shape**: a round head flowing into a single tail that tapers, bends back and curls at the tip, like a classic cartoon ghost.
  - Two flappy arms with a darker edge.
  - Hollow cartoon eyes with an optional coloured glow, and an open "oh" mouth.
  - Shading is two-tone: a lit left edge and a shadow down the right side.
- **Animation speed**: the float animations play at half their old speed.
  - Glide: about 6 fps.
  - Idle hover: 380 ms per frame.
- **Creator**: only Hat (Class, None, or any of 10 headgear), Ghost colour and Eye glow (Hollow plus 7 glows).
  - No hair, clothes or scarf.
  - `HeroArt.complete()` repairs looks saved by older versions. This fixed a crash when picking the Mage with an old saved look.
- **Gear on the ghost**: only helmets and hats from drops show on it. Armour still gives its boon, but you only see it on its loot icon.

### v0.9.2 — Cleaner ghost, Loot Lift
- **Ghost shape**: the dome head's tip flops back (only when no hat is worn). Below it a fuller belly leans forward and tapers into the single curled tail, so it reads as a sheet rather than a balloon.
- **Eyes**: two tall, clean ovals snapped to the pixel grid, placed below the hat brim. A dull shine when hollow, a coloured glow when an eye glow is picked. Small round mouth.
- **Loot Lift** (was the Extraction Lift):
  - Sends only the monster parts in the bag up to the Workshop. You and your gold stay, and the run carries on.
  - It can be used again on the same floor.
  - On death, only the parts never sent up are lost.

### v1.0 — Endless grind
- **Fixes**
  - The Camera2D warning that physics interpolation caused is gone (the camera is set to physics mode up front).
  - Shots no longer pass through walls. Each step, a projectile sweeps its path against wall bodies, and the first step starts from where it was fired. Monsters share collision layer 1 with the walls, so only StaticBody2D hits count.
  - Chain lightning can't jump through walls.
- **Heat levels** (scripts/grind.gd): chosen on the class page. Reaching depth 10 on your highest heat, after descending at least 10 floors in that run, unlocks the next level. Heat is endless.
  - Per heat level: monsters +15% HP, +2% speed and +4% elite chance. Every 3 levels, +1 damage. Every 4 levels, a starting curse.
  - Rewards per heat level: +25% Soul Shards, +15% parts, gear item level +3.
  - Best depth is tracked per heat.
- **Endless Workshop**: most recipes have no cap (`max` 0).
  - Costs rise linearly, then 12% per level after level 3.
  - Speed, crit, dodge and hearts taper toward a cap (`Materials.taper`). HP, damage, gold and part chance stay linear.
  - Powder Pouch goes up to 3, Heart Forge stays at 1.
- **Gear item level and legendaries**
  - Item level = depth + 3×heat. Boons grow 2.5% per level.
  - Legendary drop chance: 0.5% from normal monsters, 4% from elites, 15% from bosses, 20% from a slot-machine triple-sword win, and always from mutated bosses.
  - Legendaries carry a second boon with a name suffix ("of Fury" and so on) and glow orange.
  - Salvage value scales with item level and rarity.
- **Bounty Board**: three goals that count across runs. Types: slay a monster kind, elites, bosses, reach a depth, send parts up, pull the idol, find rare gear, reach a depth on a given heat.
  - Rewards are part bundles plus Soul Shards, scaled by difficulty.
  - Rerolling a bounty costs 5 shards.
- **Monster Codex**: kills per monster type. Mastery tiers at 50/250/1000 kills (bosses 5/25/100).
  - Each tier gives +6% damage against that type.
  - Tier II unlocks an eye glow, tier III a ghost colour (picked in the creator).
- **Mutated bosses** (depth 50+): chance of 25% at depth 50, +1% per depth, capped at 75%.
  - An extra attack, ×1.5 HP and a green tint.
  - Always drop a legendary.
- **Weekly Run** (save slot 4): two mutators per week, seeded from the week number and the same for everyone. Best depth is recorded per week.
  - Mutators: Glass Ghosts, Gambler's Den, Elite Horde, Frenzy, Bloodless, Loaded Dice, Eternal Night.

### v1.0.1 — Faster pace, phasing dodge
- **Pace** (`Player.PACE` = 1.2):
  - Class move speed ×1.2, charge reload ×1.2 faster, attack cooldowns ÷1.2, dodge cooldown ×0.65.
  - Monsters move 15% faster.
- **Dodge**: a quicker, longer dash (72 px in 0.17 s).
  - During the dash and for 0.12 s after it (`DODGE_GRACE`), the ghost is see-through (pale blue, 38% opacity) and can't be hurt (`Player.phase_t`).

### v1.0.2 — Web release
- **Hosting**: the web build lives in `docs/` and is served by GitHub Pages.
  - It's an installable phone app (PWA): fullscreen, landscape, and a service worker so later launches load from the device cache.
- **No Godot splash**: `boot_splash/show_image` is off, and a custom page (`web/shell.html`) shows a Depthbound loading screen with a floating ghost and a progress bar.
  - The game calls `window.depthboundReady()` once the menu is drawn (`main._signal_web_ready`), then the loading screen fades. There's a 20 s safety timeout.
- **Faster start**: sounds and music are baked once into `assets/audio/sounds.res` (`tools/bake_audio.gd`) instead of being synthesized at every start, which took about 1 s on the web.
- **Updating the site**:
  1. Export the "Web" preset to `docs/index.html`.
  2. Commit and push.

### v1.1 — Ghostbound: story, rebrand and leveling
- **Story**: you died on floor 999 and are now a ghost. Your body is still down there, so you descend to take it back.
  - The menu and loading screen show this as a tagline; floor 1 repeats it.
  - The HUD reads "Floor N / 999".
  - Dying again is "YOU FADED".
  - Reaching floor 999 offers a choice: take your body back (ends the run with ×3 shards, title "REUNITED!", counted in `Profile.data.reunited`) or keep haunting deeper.
- **Rebrand**: the game is now called Ghostbound, with a ghost app icon (`icon.svg`) and a renamed loading screen, window title, PWA name and Windows exe.
  - `config/custom_user_dir_name` still points at `Godot/app_userdata/Depthbound`, so PC saves carry over.
  - The web URL (`/depthbound/`) and the internal JS hook `depthboundReady` keep their old names.
- **Run level** (`scripts/leveling.gd`):
  - Kills give XP: 1 for normal foes, 2 for brutes, golems and cultists, ×3 for elites, 25 for bosses.
  - Reaching the next level takes `10 + 5×level` XP, which works out to roughly level 7 by floor 10 and level 14 by floor 20.
  - Each level gives +3% damage and heals 1. Every 3rd level adds +1 max HP.
  - Every 5th level offers a choice of 3 perks: 3 universal ones plus 3 for each class.
    - Unique-mechanic perks: Shockwave, Shadow Strike, Volley, Arcane Nova, Second Soul.
    - The rest are strong stat bundles.
  - The level, XP, perks and `soul_used` are saved with the run.
  - A perk choice that comes up while another panel is open waits until that panel closes (`_pending_perks`).
- **Ghost Level** (account):
  - All XP from every run also feeds a permanent level that needs `150 + 50×level` XP.
  - Each level pays `10 + 2×level` shards plus two kinds of monster parts. Every 5th level also pays a Boss Heart.
  - Permanent bonus: +1% damage per level (up to +50%) and +1 max HP per 10 levels (up to +3).
  - The menu shows the Ghost Level and its bonus; the game-over screen shows the run's level and XP.

### v1.1.1 — Browser sound fix and boss arenas
- **Browser sound**: the web build plays sounds through the browser's own audio system ("sample" playback).
  - That system only knows about audio buses that exist when the game starts. The SFX and Music buses used to be added at runtime, so every sound was created but never played.
  - They are now declared in `default_bus_layout.tres`. `Audio._ensure_bus` is now only a fallback.
- **Boss floors** are one big arena (`DungeonGenerator.arena`):
  - A rounded hall of 40×30 tiles, growing slowly with depth, with four 2×2 pillars for cover.
  - You start at the bottom; the boss and the locked stairs are at the top.
  - No other monsters spawn, apart from anything the boss summons itself.
  - The Loot Lift stands beside the start.
