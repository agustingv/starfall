/*
 * PlayScreen: the campaign. Owns the world (player, pools, boss, starfield) and
 * a small phase machine that walks each level through its three sections and a
 * boss, then on to the next level or the victory screen.
 *
 *   LEVEL_INTRO -> SECTION x3 (with SECTION_CLEAR banners)
 *               -> BOSS_INTRO -> BOSS -> LEVEL_CLEAR
 *               -> next LEVEL_INTRO, or VICTORY after level 5
 *   player out of lives -> DEAD
 *   DEAD / VICTORY -> ENTER_NAME (if the score makes the top 10) -> SCORE_TABLE
 *                  -> back to the title
 */

namespace Starfall {

    enum Phase {
        LEVEL_INTRO,
        SECTION,
        SECTION_CLEAR,
        BOSS_INTRO,
        BOSS,
        LEVEL_CLEAR,
        DEAD,
        VICTORY,
        ENTER_NAME,
        SCORE_TABLE,
    }

    public class PlayScreen : Screen {
        Player       player;
        BulletPool   bullets;
        EnemyPool    enemies;
        Boss         boss;
        Starfield    starfield;
        Planet       planet;
        EnemyBeamPool beams;
        ExplosionPool fx;
        MissilePool   missiles;
        PickupPool    pickups;

        int level   = 1;
        int section = 1;
        int score   = 0;

        Phase phase;
        float phase_t;        // seconds in the current phase
        bool  paused;
        int   pause_sel;      // Esc menu: 0 = resume, 1 = main menu

        SectionScript script;
        int   fired;          // spawn events fired so far this section
        float section_t;

        // High-score name entry.
        char[] name_ch;
        int    name_slot;
        int    entry_rank;       // 1-based rank being entered, for display
        int    table_highlight;  // row just added to the table, or -1

        public PlayScreen (Game game) {
            base (game);
            bullets   = new BulletPool ();
            enemies   = new EnemyPool ();
            boss      = new Boss ();
            starfield = new Starfield ();
            planet    = new Planet ();
            beams     = new EnemyBeamPool ();
            fx        = new ExplosionPool ();
            missiles  = new MissilePool ();
            pickups   = new PickupPool ();
            player    = new Player ();
            name_ch   = { 'A', 'A', 'A' };
        }

        public override void on_enter () {
            begin_level_intro ();
        }

        /* ---- Phase transitions ------------------------------------------ */

        void set_phase (Phase p) {
            phase = p;
            phase_t = 0.0f;
            paused = false;
        }

        void begin_level_intro () {
            bullets.clear ();
            enemies.clear ();
            beams.clear ();
            fx.clear ();
            missiles.clear ();
            pickups.clear ();
            boss.active = false;
            planet.set_level (level);
            player.recenter ();
            set_phase (Phase.LEVEL_INTRO);
        }

        void begin_section (int n) {
            section   = n;
            script    = new SectionScript (level, n);
            fired     = 0;
            section_t = 0.0f;
            set_phase (Phase.SECTION);
        }

        void begin_boss_intro () {
            bullets.clear ();
            enemies.clear ();
            beams.clear ();
            missiles.clear ();
            pickups.clear ();
            player.recenter ();
            set_phase (Phase.BOSS_INTRO);
        }

        void begin_boss () {
            boss.spawn (level);
            set_phase (Phase.BOSS);
        }

        /* ---- Input (per frame) ------------------------------------------- */

        public override void handle_input () {
            bool in_fight = (phase == Phase.SECTION || phase == Phase.BOSS);

            if (in_fight && paused) {
                handle_pause_menu ();
                return;
            }

            if (in_fight && Raylib.is_key_pressed (Raylib.KeyboardKey.ESCAPE)) {
                paused    = true;
                pause_sel = 0;
                Audio.instance ().play ("ui_select");
                return;
            }

            if (in_fight && special_pressed () && player.use_special ())
                launch_special ();

            switch (phase) {
                case Phase.DEAD:
                    if (phase_t >= 0.5f && nav_confirm ()) finish_run ();
                    break;
                case Phase.VICTORY:
                    if (phase_t >= 1.0f && nav_confirm ()) finish_run ();
                    break;
                case Phase.ENTER_NAME:
                    handle_name_input ();
                    break;
                case Phase.SCORE_TABLE:
                    if (phase_t >= 0.4f && nav_confirm ()) game.goto_title ();
                    break;
                default:
                    break;
            }
        }

        /* Decide what happens once a run ends: initials entry if the score
         * makes the table, otherwise straight to the table. */
        void finish_run () {
            if (HighScores.instance ().qualifies (score)) {
                entry_rank      = HighScores.instance ().rank_for (score);
                name_ch         = { 'A', 'A', 'A' };
                name_slot       = 0;
                table_highlight = -1;
                set_phase (Phase.ENTER_NAME);
            } else {
                table_highlight = -1;
                set_phase (Phase.SCORE_TABLE);
            }
        }

        void handle_name_input () {
            int slot = int.max (0, int.min (2, name_slot));

            // Direct typing.
            int ch = Raylib.get_char_pressed ();
            while (ch > 0) {
                if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
                    name_ch[slot] = (char) ((ch >= 'a') ? ch - 32 : ch);
                    if (name_slot < 2) { name_slot++; slot = name_slot; }
                }
                ch = Raylib.get_char_pressed ();
            }

            if (Raylib.is_key_pressed (Raylib.KeyboardKey.BACKSPACE) && name_slot > 0)
                name_slot--;

            bool pad = Raylib.is_gamepad_available (0);
            if (Raylib.is_key_pressed (Raylib.KeyboardKey.UP)
                || (pad && Raylib.is_gamepad_button_pressed (0, Raylib.GamepadButton.LEFT_FACE_UP)))
                name_ch[slot] = cycle_letter (name_ch[slot], 1);
            if (Raylib.is_key_pressed (Raylib.KeyboardKey.DOWN)
                || (pad && Raylib.is_gamepad_button_pressed (0, Raylib.GamepadButton.LEFT_FACE_DOWN)))
                name_ch[slot] = cycle_letter (name_ch[slot], -1);
            if (Raylib.is_key_pressed (Raylib.KeyboardKey.LEFT)
                || (pad && Raylib.is_gamepad_button_pressed (0, Raylib.GamepadButton.LEFT_FACE_LEFT)))
                name_slot = int.max (0, name_slot - 1);
            if (Raylib.is_key_pressed (Raylib.KeyboardKey.RIGHT)
                || (pad && Raylib.is_gamepad_button_pressed (0, Raylib.GamepadButton.LEFT_FACE_RIGHT)))
                name_slot = int.min (2, name_slot + 1);

            if (Raylib.is_key_pressed (Raylib.KeyboardKey.ENTER)
                || (pad && Raylib.is_gamepad_button_pressed (0, Raylib.GamepadButton.RIGHT_FACE_DOWN))) {
                table_highlight = HighScores.instance ().add (initials_string (), score, level);
                Audio.instance ().play ("ui_select");
                set_phase (Phase.SCORE_TABLE);
            }
        }

        string initials_string () {
            return ((unichar) name_ch[0]).to_string ()
                 + ((unichar) name_ch[1]).to_string ()
                 + ((unichar) name_ch[2]).to_string ();
        }

        static char cycle_letter (char c, int dir) {
            int v = c - 'A';
            if (v < 0 || v > 25) v = 0;
            v = (v + dir + 26) % 26;
            return (char) ('A' + v);
        }

        static bool special_pressed () {
            return Raylib.is_key_pressed (Raylib.KeyboardKey.X)
                || Raylib.is_key_pressed (Raylib.KeyboardKey.LEFT_SHIFT)
                || (Raylib.is_gamepad_available (0)
                    && Raylib.is_gamepad_button_pressed (0, Raylib.GamepadButton.RIGHT_FACE_LEFT));
        }

        /* Esc pause menu: arrow keys move between Resume / Main Menu, Enter
         * confirms, Esc resumes. The simulation is frozen while this is up. */
        void handle_pause_menu () {
            int prev = pause_sel;
            if (nav_up ())   pause_sel--;
            if (nav_down ()) pause_sel++;
            pause_sel = (pause_sel + 2) % 2;
            if (pause_sel != prev)
                Audio.instance ().play ("ui_move");

            if (Raylib.is_key_pressed (Raylib.KeyboardKey.ESCAPE)) {
                paused = false;
                Audio.instance ().play ("ui_select");
                return;
            }

            if (nav_confirm ()) {
                Audio.instance ().play ("ui_select");
                if (pause_sel == 0) paused = false;
                else                game.goto_title ();
            }
        }

        /* Fire the special: one homing missile per enemy on screen (capped by
         * the pool), fanned upward, plus a few unguided ones for stragglers. */
        void launch_special () {
            Audio.instance ().play ("special");

            int launched = 0;
            foreach (var e in enemies.items) {
                if (!e.active) continue;
                float ang = Raylib.get_random_value (-70, 70) / 100.0f;
                if (missiles.launch (player.pos, ang, e) == null)
                    break;
                launched++;
            }

            int extra = int.min (6, MissilePool.CAP - launched);
            for (int i = 0; i < extra; i++) {
                float ang = (extra > 1) ? (-0.9f + 1.8f * i / (extra - 1)) : 0.0f;
                missiles.launch (player.pos, ang, null);
            }
        }

        /* ---- Update (fixed step) --------------------------------------- */

        public override void update (float dt) {
            starfield.update (dt);
            planet.update (dt);

            bool in_fight = (phase == Phase.SECTION || phase == Phase.BOSS);
            if (paused && in_fight)
                return;

            phase_t += dt;

            switch (phase) {
                case Phase.LEVEL_INTRO:
                    if (phase_t >= 3.0f) begin_section (1);
                    break;

                case Phase.SECTION:
                    run_section (dt);
                    break;

                case Phase.SECTION_CLEAR:
                    if (phase_t >= 1.6f) {
                        if (section >= Config.SECTIONS_PER_LEVEL) begin_boss_intro ();
                        else                                       begin_section (section + 1);
                    }
                    break;

                case Phase.BOSS_INTRO:
                    if (phase_t >= 2.2f) begin_boss ();
                    break;

                case Phase.BOSS:
                    run_boss (dt);
                    break;

                case Phase.LEVEL_CLEAR:
                    if (phase_t >= 2.6f) {
                        if (level >= Config.LEVELS) {
                            set_phase (Phase.VICTORY);
                        } else {
                            level++;
                            section = 1;
                            begin_level_intro ();
                        }
                    }
                    break;

                case Phase.DEAD:
                    if (phase_t >= 2.4f) finish_run ();
                    break;

                case Phase.VICTORY:
                    break;   // waits for confirm (handle_input)

                case Phase.ENTER_NAME:
                    break;   // driven entirely by handle_input

                case Phase.SCORE_TABLE:
                    if (phase_t >= 12.0f) game.goto_title ();
                    break;
            }
        }

        void run_section (float dt) {
            section_t += dt;

            while (fired < script.events.length && section_t >= script.events[fired].at) {
                Formations.spawn (enemies, script.events[fired].formation, script.events[fired].kind);
                fired++;
            }

            step_world (dt);

            if (player.alive
                && fired >= script.events.length
                && enemies.active_count () == 0
                && section_t >= script.last_at + 2.5f) {
                set_phase (Phase.SECTION_CLEAR);
            }
        }

        void run_boss (float dt) {
            boss.update (dt, bullets, player);
            step_world (dt);

            if (player.alive && !boss.active) {
                score += 1000 * level;
                set_phase (Phase.LEVEL_CLEAR);
            }
        }

        /* Player + projectiles + collisions - the part common to every fight. */
        void step_world (float dt) {
            Input input = Player.read_input ();
            player.update (dt, input, bullets);
            enemies.update (dt, bullets, beams, player);
            bullets.update (dt, player);
            beams.update (dt);
            missiles.update (dt);
            pickups.update (dt);
            fx.update (dt);

            bool was_alive = player.alive;
            int  lives_before = player.lives;
            resolve_collisions ();

            if (was_alive && !player.alive) {
                fx.spawn (player.pos, player.radius * 4.0f);
                Audio.instance ().play ("explosion_big");
                set_phase (Phase.DEAD);
            } else if (player.lives < lives_before) {
                Audio.instance ().play ("hit");
            }
        }

        void resolve_collisions () {
            // Player shots vs boss, then vs enemies.
            foreach (var b in bullets.items) {
                if (!b.active || !b.from_player) continue;

                if (boss.hittable ()
                    && Raylib.check_collision_circles (b.pos, b.radius, boss.pos, boss.radius)) {
                    b.active = false;
                    boss.damage (1.0f);
                    fx.spawn ({ b.pos.x, b.pos.y }, 14.0f);
                    if (!boss.active) {
                        score += 500 * level;
                        for (int k = 0; k < 6; k++)
                            fx.spawn ({ boss.pos.x + Raylib.get_random_value (-30, 30),
                                        boss.pos.y + Raylib.get_random_value (-24, 24) },
                                      boss.radius * 1.4f);
                        Audio.instance ().play ("explosion_big");
                    }
                    continue;
                }

                foreach (var e in enemies.items) {
                    if (!e.active) continue;
                    if (Raylib.check_collision_circles (b.pos, b.radius, e.pos, e.radius)) {
                        b.active = false;
                        e.hp -= 1.0f;
                        if (e.hp <= 0.0f) {
                            e.active = false;
                            score += e.score_value;
                            fx.spawn (e.pos, e.radius * 3.2f);
                            Audio.instance ().play ("explosion_small", 0.12f);
                            if (Raylib.get_random_value (0, 99) < Config.SPECIAL_DROP_PCT)
                                pickups.spawn (e.pos);
                        }
                        break;
                    }
                }
            }

            // Special-weapon missiles vs boss / enemies.
            foreach (var m in missiles.items) {
                if (!m.active) continue;

                if (boss.hittable ()
                    && Raylib.check_collision_circles (m.pos, m.radius, boss.pos, boss.radius)) {
                    m.active = false;
                    boss.damage (1.0f);
                    fx.spawn (m.pos, 16.0f);
                    continue;
                }

                foreach (var e in enemies.items) {
                    if (!e.active) continue;
                    if (Raylib.check_collision_circles (m.pos, m.radius, e.pos, e.radius)) {
                        m.active = false;
                        e.active = false;
                        score += e.score_value;
                        fx.spawn (e.pos, e.radius * 3.2f);
                        Audio.instance ().play ("explosion_small", 0.16f);
                        break;
                    }
                }
            }

            // Player fire can shoot down incoming guided missiles.
            foreach (var mb in bullets.items) {
                if (!mb.active || mb.from_player || !mb.missile) continue;

                bool killed = false;
                foreach (var b in bullets.items) {
                    if (!b.active || !b.from_player) continue;
                    if (Raylib.check_collision_circles (b.pos, b.radius, mb.pos, mb.radius)) {
                        b.active = false;
                        killed = true;
                        break;
                    }
                }
                if (!killed) {
                    foreach (var m in missiles.items) {
                        if (!m.active) continue;
                        if (Raylib.check_collision_circles (m.pos, m.radius, mb.pos, mb.radius)) {
                            m.active = false;
                            killed = true;
                            break;
                        }
                    }
                }
                if (killed) {
                    mb.active = false;
                    fx.spawn (mb.pos, 14.0f);
                    score += 25;
                    Audio.instance ().play ("hit", 0.16f, 0.45f);
                }
            }

            // Recharge pickups vs player (grabbable even while immune).
            foreach (var p in pickups.items) {
                if (!p.active) continue;
                if (Raylib.check_collision_circles (p.pos, p.radius,
                                                    player.pos, player.radius + 6.0f)) {
                    p.active = false;
                    if (player.special_charges < Player.SPECIAL_MAX) {
                        player.add_special_charge ();
                        Audio.instance ().play ("powerup");
                    } else {
                        score += 200;
                        Audio.instance ().play ("powerup", 0.0f, 0.6f);
                    }
                }
            }

            if (player.invulnerable) return;

            if (beams.strike (player)) {
                player.hit ();
                return;
            }

            foreach (var b in bullets.items) {
                if (!b.active || b.from_player) continue;
                if (Raylib.check_collision_circles (b.pos, b.radius, player.pos, player.radius)) {
                    b.active = false;
                    player.hit ();
                    return;
                }
            }
            foreach (var e in enemies.items) {
                if (!e.active) continue;
                if (Raylib.check_collision_circles (e.pos, e.radius, player.pos, player.radius)) {
                    e.active = false;
                    fx.spawn (e.pos, e.radius * 3.2f);
                    player.hit ();
                    return;
                }
            }
            if (boss.hittable ()
                && Raylib.check_collision_circles (boss.pos, boss.radius, player.pos, player.radius)) {
                player.hit ();
            }
        }

        /* ---- Draw --------------------------------------------------------- */

        public override void draw () {
            planet.draw ();
            starfield.draw ();
            pickups.draw ();
            enemies.draw ();
            if (phase == Phase.BOSS && boss.active) boss.draw ();
            beams.draw ();
            bullets.draw ();
            missiles.draw ();
            if (player.alive) player.draw ();
            fx.draw ();

            draw_hud ();

            switch (phase) {
                case Phase.LEVEL_INTRO:
                    draw_level_intro ();
                    break;
                case Phase.SECTION_CLEAR:
                    draw_banner (@"SECTION $(level)-$(section) CLEAR");
                    break;
                case Phase.BOSS_INTRO:
                    draw_boss_warning ();
                    break;
                case Phase.BOSS:
                    boss.draw_health_bar ();
                    break;
                case Phase.LEVEL_CLEAR:
                    draw_banner (@"LEVEL $(level) CLEAR");
                    break;
                case Phase.DEAD:
                    draw_overlay ("GAME OVER", "the Earth stays under their shadow");
                    break;
                case Phase.VICTORY:
                    draw_overlay ("EARTH LIBERATED", "press enter");
                    break;
                case Phase.ENTER_NAME:
                    draw_enter_name ();
                    break;
                case Phase.SCORE_TABLE:
                    draw_score_table ();
                    break;
                default:
                    break;
            }

            if (paused && (phase == Phase.SECTION || phase == Phase.BOSS))
                draw_pause_menu ();
        }

        void draw_pause_menu () {
            Raylib.draw_rectangle (0, 0, Config.SCREEN_W, Config.SCREEN_H,
                                   Raylib.fade (Palette.BLACK, 0.65f));

            int mid = Config.SCREEN_H / 2;
            draw_text_centered ("PAUSED", mid - 96, 44, Palette.RAYWHITE);

            string[] opts = { "RESUME", "MAIN MENU" };
            int menu_y = mid - 8;
            for (int i = 0; i < opts.length; i++) {
                bool sel  = (i == pause_sel);
                int  size = sel ? 30 : 26;
                var  col  = sel ? Palette.YELLOW : Palette.LIGHTGRAY;
                string label = sel ? @"> $(opts[i])  <" : opts[i];
                draw_text_centered (label, menu_y, size, col);
                menu_y += 52;
            }

            draw_text_centered ("arrows to choose  -  enter to confirm  -  esc to resume",
                                mid + 120, 13, Palette.GRAY);
        }

        void draw_hud () {
            Raylib.draw_text ("SCORE %08d".printf (score), 12, 12, 20, Palette.RAYWHITE);

            string tag = (phase == Phase.BOSS || phase == Phase.BOSS_INTRO)
                ? @"LEVEL $(level)  BOSS"
                : @"LEVEL $(level)-$(section)";
            int tw = Raylib.measure_text (tag, 18);
            Raylib.draw_text (tag, (Config.SCREEN_W - tw) / 2, 14, 18, Palette.SKYBLUE);

            for (int i = 0; i < player.lives; i++) {
                float x = Config.SCREEN_W - 22.0f - i * 20.0f;
                Raylib.draw_triangle ({ x, 14.0f }, { x - 7.0f, 30.0f }, { x + 7.0f, 30.0f },
                                      Palette.LIME);
            }

            // Special-weapon charges (cyan diamonds under the score).
            for (int i = 0; i < player.special_charges; i++) {
                float x = 20.0f + i * 22.0f;
                Raylib.draw_triangle ({ x, 38.0f }, { x - 8.0f, 46.0f }, { x + 8.0f, 46.0f },
                                      Palette.SKYBLUE);
                Raylib.draw_triangle ({ x - 8.0f, 46.0f }, { x, 54.0f }, { x + 8.0f, 46.0f },
                                      Palette.SKYBLUE);
            }

            Raylib.draw_fps (12, Config.SCREEN_H - 26);
        }

        void draw_level_intro () {
            Raylib.draw_rectangle (0, 0, Config.SCREEN_W, Config.SCREEN_H,
                                   Raylib.fade (Palette.BLACK, 0.55f));
            draw_text_centered (@"LEVEL $(level)", Config.SCREEN_H / 2 - 70, 30, Palette.LIGHTGRAY);
            draw_text_centered (Levels.title (level), Config.SCREEN_H / 2 - 30, 40, Palette.RAYWHITE);
            draw_text_centered (Levels.tagline (level), Config.SCREEN_H / 2 + 24, 15, Palette.SKYBLUE);
        }

        void draw_boss_warning () {
            bool on = ((int) (phase_t * 4.0)) % 2 == 0;
            draw_banner (on ? @"WARNING - $(Levels.boss_name (level))" : "WARNING");
        }

        void draw_enter_name () {
            Raylib.draw_rectangle (0, 0, Config.SCREEN_W, Config.SCREEN_H,
                                   Raylib.fade (Palette.BLACK, 0.72f));

            int mid = Config.SCREEN_H / 2;
            draw_text_centered ("NEW HIGH SCORE", mid - 150, 34, Palette.YELLOW);
            draw_text_centered ("RANK #%d      SCORE %08d".printf (entry_rank, score),
                                mid - 106, 18, Palette.LIGHTGRAY);

            int cx = Config.SCREEN_W / 2;
            int gap = 56;
            for (int i = 0; i < 3; i++) {
                int x = cx + (i - 1) * gap;
                bool act = (i == name_slot);
                var col = act ? Palette.WHITE : Palette.SKYBLUE;

                string s = ((unichar) name_ch[i]).to_string ();
                int w = Raylib.measure_text (s, 56);
                Raylib.draw_text (s, x - w / 2, mid - 56, 56, col);

                if (act && ((int) (Raylib.get_time () * 3.0)) % 2 == 0)
                    Raylib.draw_rectangle (x - 20, mid + 12, 40, 4, Palette.YELLOW);
            }

            draw_text_centered ("type initials  -  up/down change  -  enter",
                                mid + 74, 15, Palette.GRAY);
        }

        void draw_score_table () {
            Raylib.draw_rectangle (0, 0, Config.SCREEN_W, Config.SCREEN_H,
                                   Raylib.fade (Palette.BLACK, 0.78f));
            HighScores.instance ().draw_table (table_highlight);
            if (((int) (phase_t * 2.0)) % 2 == 0)
                draw_text_centered ("enter to continue", Config.SCREEN_H - 58, 16,
                                    Palette.LIGHTGRAY);
        }
    }
}
