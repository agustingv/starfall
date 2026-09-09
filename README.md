# Starfall

A vertical-scrolling arcade shoot-'em-up scaffold: one ship, waves of aliens,
written in **Vala** on top of **raylib 5.5**.

This is a starting point, not a finished game. It gives you a working build, a
title screen, a fixed-timestep game loop, pooled entities, a five-level campaign
skeleton with bosses, procedurally generated sprites, explosions, parallax
stars, and a HUD — enough structure to start adding real content.

## Story

An alien civilisation from Andromeda has invaded Earth. Humanity's last
squadrons launch from the base on **Titan** and burn sunward to break the
occupation. Five levels — Titan, the asteroid belt, Mars, the Moon, Earth — each
with three sections and a boss that has to fall before the next world opens.

## Build & run

```sh
meson setup build
meson compile -C build
./build/starfall
```

Requires: `valac`, `meson`, `ninja`, a C compiler, and the X11 / OpenGL
development headers (`libgl-dev`, `libx11-dev`, `libxrandr-dev`, `libxinerama-dev`,
`libxi-dev`, `libxcursor-dev`). raylib itself is **not** required on the system —
if pkg-config doesn't find it, Meson downloads and builds the pinned version from
`subprojects/raylib.wrap` (uses raylib's own Makefile; see
`subprojects/packagefiles/raylib/`). If you *do* have a system raylib >= 5.0, it's
used instead.

## Controls

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Menu: move / confirm | Arrows or WASD / Enter or Space | D-pad / A |
| Move   | Arrows / WASD | Left stick / D-pad |
| Fire   | Space | A / cross |
| Special weapon | X or Left Shift | X / square |
| Pause  | Esc (menu: **Resume** / **Main Menu**) | – |
| Fullscreen | F | – |
| Initials entry | type A–Z, or Up/Down + Left/Right, Enter | D-pad + A |
| Quit   | **Exit** on the title, or the window close button | – |

The title menu is **Play** (new campaign at 1-1), **Scores** (the high-score
table), and **Exit**. When a run ends — game over or victory — a score that
makes the top 10 gets an arcade initials-entry screen, then the table; either
way it returns to the title afterwards.

## Layout

```
meson.build                  build definition
vapi/raylib.vapi             hand-written raylib bindings (extend as needed)
tools/gen_sprites.py         procedural sprite generator -> assets/sprites/
tools/gen_sounds.py          procedural sound generator  -> assets/sounds/
assets/sprites/              atlas.png + atlas.txt (+ per-sprite PNGs, preview.png)
assets/sounds/               *.wav sound effects
subprojects/
  raylib.wrap                fetches raylib 5.5
  packagefiles/raylib/       Meson shim that drives raylib's Makefile
src/
  main.vala                  entry point
  game.vala                  Game: window, backbuffer, fixed-timestep loop, screen switching
  screen.vala                Screen base class + shared menu nav / text helpers
  title_screen.vala          TitleScreen: story, starfield, Play / Scores / Exit
  play_screen.vala           PlayScreen: the campaign — world + phase machine
  score_screen.vala          ScoreScreen: the high-score table from the menu
  level.vala                 campaign text, SectionScript, Formations
  boss.vala                  Boss: one parameterised craft, scaled per level
  scores.vala                HighScores: top-10 table, load / save / draw
  entity.vala                Config tunables, Input struct, Entity base, Palette
  player.vala                ship movement, cannon, lives, invulnerability
  bullet.vala                Bullet + BulletPool (incl. guided-missile homing)
  enemy.vala                 Enemy (8 kinds, per-level roster) + EnemyPool
  beam.vala                  EnemyBeam + EnemyBeamPool (the SENTINEL's laser)
  special.vala               MissilePool (special weapon) + PickupPool (recharges)
  starfield.vala             parallax background
  planet.vala                per-level backdrop world (Titan .. Earth)
  assets.vala                Assets: loads the sprite atlas, blits named regions
  audio.vala                 Audio: loads the wav effects, round-robin voices
  fx.vala                    ExplosionPool
```

## Art / sprites

Sprites are **procedurally generated** by `tools/gen_sprites.py` (Pillow +
numpy) — original pixel-art ships, bullets and an explosion sheet, drawn from
maths, not traced from any asset pack. Regenerate after editing the script:

```sh
python3 tools/gen_sprites.py
```

It writes `assets/sprites/atlas.png` (one packed texture) and
`assets/sprites/atlas.txt` (a `name x y w h frames` manifest the game reads),
plus each sprite as its own PNG and a 6× `preview.png` contact sheet.

At runtime `Assets` looks for the sprite folder in `$STARFALL_ASSETS`, then
`./assets/sprites`, then next to / above the executable, then
`<prefix>/share/starfall/sprites` (the install path). **If it finds nothing the
game still runs** — every `draw()` falls back to the primitive shapes, and
`Assets.instance ().draw_sprite ()` just returns `false`.

To use real art instead: drop your own `atlas.png` + `atlas.txt` in
`assets/sprites/` with the same region names (`player`, `enemy_grunt`,
`enemy_darter`, `enemy_weaver`, `enemy_sentinel`, `enemy_brute`, `enemy_hunter`,
`enemy_racer`, `enemy_warden`, `boss_1`..`boss_5`, `bullet_player`,
`bullet_enemy`, `missile`, `pickup`, `explosion`, `planet_1`..`planet_5`), or
point `$STARFALL_ASSETS` at your own folder.
Tune the on-screen size per entity via the `dest_h` multiplier in each
`draw ()`.

## Sound

Sound effects are also **synthesised** — `tools/gen_sounds.py` (numpy + the
stdlib `wave` module, no other deps) writes 16-bit mono WAVs:

```sh
python3 tools/gen_sounds.py
```

| file | used for |
|---|---|
| `shot_player.wav` | player blaster |
| `shot_enemy.wav` | enemy + boss fire |
| `explosion_small.wav` | enemy destroyed |
| `explosion_big.wav` | boss / player destroyed |
| `hit.wav` | player takes a hit |
| `special.wav` | special weapon launch |
| `powerup.wav` | recharge pickup collected |
| `ui_move.wav` / `ui_select.wav` | title menu |

`Audio` (in `audio.vala`) loads them after the audio device comes up, giving
each effect four raylib *sound aliases* it cycles round-robin so rapid fire
overlaps cleanly. `play (name, pitch_jitter, volume)` is the only entry point.
Folder search mirrors the sprites: `$STARFALL_SOUNDS`, `./assets/sounds`, next
to / above the exe, `<prefix>/share/starfall/sounds`. **No files or no audio
device → the game just runs silent.** Replace the WAVs in place (same names) to
use your own.

## High scores

The top 10 are kept in `HighScores` (`scores.vala`) and persisted between runs
to a plain text file — `$STARFALL_SCORES` if set, otherwise
`$XDG_DATA_HOME/starfall/highscores.txt` (usually
`~/.local/share/starfall/highscores.txt`), one `INITIALS SCORE LEVEL` per line.
A fresh install is seeded with placeholder scores so the table is never empty.

When a run ends, `PlayScreen.finish_run()` asks `HighScores.qualifies(score)`;
if it makes the cut the `ENTER_NAME` phase takes 3 initials (type them, or
cycle with the arrows + gamepad), then `add()` inserts, re-sorts, clamps to 10
and saves. The `SCORE_TABLE` phase (and the menu's `ScoreScreen`) both render
via `HighScores.draw_table(highlight_row)`.

## Architecture notes

- **Fixed timestep.** `Game.run()` accumulates real frame time and steps the
  simulation in fixed `Config.TICK` (1/60 s) slices, so behaviour is
  frame-rate-independent. Rendering happens once per real frame.
- **Fixed logical resolution.** All game code draws at `Config.SCREEN_W` ×
  `SCREEN_H` (480×720) into an offscreen `RenderTexture2D`. `Game.present()`
  blits that to the real window scaled to fit and centred, with black bars for
  the leftover. The window itself is sized to ~90% of the monitor on startup
  (`size_window_to_monitor()`) and is resizable; `F` toggles fullscreen. Change
  the two `Config` values to re-shape the play field — nothing else needs to
  move. Swap `TextureFilter.POINT` for `BILINEAR` in `run()` if you prefer
  smooth scaling to crisp pixels.
- **Screens.** `Game` owns one `Screen` at a time and forwards update/draw to
  it. Screens call `game.start_new_game()` / `goto_title()` / `request_quit()`
  to transition. Add screens (options, level select, intro cutscene) by
  subclassing `Screen`.
- **Campaign phase machine.** `PlayScreen` walks a `Phase` enum:
  `LEVEL_INTRO → SECTION ×3 (with SECTION_CLEAR banners) → BOSS_INTRO → BOSS →
  LEVEL_CLEAR`, then the next level or `VICTORY`; running out of lives goes to
  `DEAD`. `DEAD` and `VICTORY` both feed into `ENTER_NAME` (when the score makes
  the top 10) then `SCORE_TABLE`, then back to the title. `Config.LEVELS` and
  `Config.SECTIONS_PER_LEVEL` set the shape.
- **Sections.** A section is a `SectionScript` — a timed list of `SpawnEvent`s
  (`at`, `Formation`, `EnemyKind`). It's cleared once every event has fired and
  no enemies remain. Only the *scaling* is authored right now (`bursts` / `gap`
  off the level+section index); swap the `SectionScript` body for a real
  per-section timeline when you design levels. `Formations.spawn()` maps a
  `Formation` to positions.
- **Enemies.** Eight kinds (`enemy.vala`), each with its own movement and
  weapon: GRUNT/DARTER/WEAVER/BRUTE fire plasma bolts (single, burst, angled
  pair, three-way spread); SENTINEL parks in a hold band and fires a charged
  **laser beam** (`beam.vala` — a telegraph line, then a damaging beam locked to
  its aim); HUNTER and WARDEN launch **guided missiles** that home on the player
  and can be shot down by player fire (+25). `SectionScript.roster(level)` sets
  which kinds a level draws from, so every stage fights differently.
- **Bosses.** One `Boss` class, `spawn(level)` scales hp / fire rate / colour.
  Cycles four patterns (spread, spiral, aimed burst, homing missiles); missiles
  home via `BulletPool` like the enemy craft. Boss shots reuse the normal
  `BulletPool`.
- **Special weapon.** `Player` starts with `SPECIAL_MAX` (2) charges. `X` /
  Left Shift spends one: `PlayScreen.launch_special()` fires a `MissilePool`
  swarm — one homing missile per on-screen enemy (capped at 28) plus a few
  unguided ones — and `Player.use_special()` grants 3 s of immunity. Missiles
  do 1 damage to a boss. Destroyed enemies have a `Config.SPECIAL_DROP_PCT`
  (12%) chance to drop a `Pickup`; touching one calls `add_special_charge()`
  (capped at `SPECIAL_MAX`), collectible even while immune. Missile-kills don't
  drop pickups, so a bomb can't refill itself.
- **Pools.** Bullets and enemies are pre-allocated arrays with an `active` flag.
  `spawn()` finds a free slot; nothing is allocated or freed during play. Bump
  `BulletPool.CAP` / `EnemyPool.CAP` if you need more on screen.
- **Collisions.** Brute-force circle checks in `PlayScreen.resolve_collisions()`.
  Fine for a few hundred entities. Add a uniform grid only if profiling says so.
  Note the hitboxes are the full sprite radius here — shrink them for a fairer
  bullet-hell feel.

## Where to go next

- **Better art.** Swap the generated `assets/sprites/atlas.png` for hand-drawn
  pixel art (keep the region names), or push `tools/gen_sprites.py` further —
  animation frames, banking sprites, damage states.
- **Music.** `Audio` only does one-shot effects; add a streamed `Music` track
  with raylib's `LoadMusicStream` / `UpdateMusicStream`.
- **More juice.** Screen shake, hit flashes, muzzle flashes, boss death
  sequences (there's already an `ExplosionPool` in `fx.vala` to build on).
- **Real levels.** Replace the procedural `SectionScript` with authored spawn
  timelines and give each boss its own movement / attack patterns.
- **Score detail.** The table stores initials / score / level; extend
  `ScoreEntry` with a date or per-level breakdown, or show it on the title.

## Packaging as a GNOME / Flatpak app

The scaffold opens a raylib (GLFW) window, so it won't use GTK/libadwaita
chrome, but it still packages cleanly as a Flatpak: use the
`org.freedesktop.Platform` runtime, build with this Meson project, ship a
`.desktop` file and an icon, and it will appear as a normal app on GNOME.
