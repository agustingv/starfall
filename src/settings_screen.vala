/*
 * SettingsScreen: reached from the title menu. Adjusts the sound-effects
 * volume (left / right) and shows reference info - the controls, the legend
 * for enemy drops, and how many craft each stage releases
 * (SectionScript.enemy_count). Enter or Esc returns to the title.
 */

namespace Starfall {

    public class SettingsScreen : Screen {
        Starfield stars;
        int cursor_y;   // running y for the info rows, advanced by the helpers

        const string[,] KEYS = {
            { "Move",           "Arrows / WASD  -  stick / D-pad" },
            { "Fire",           "Space  -  A / cross" },
            { "Special / Bomb", "X or Left Shift  -  square" },
            { "Pause menu",     "Esc" },
            { "Fullscreen",     "F" },
        };

        // Parallel to DROP_TEXT; glyph + colour come from PickupKind.
        const PickupKind[] DROPS = {
            PickupKind.BOMB, PickupKind.SHIELD,
            PickupKind.W_SPREAD, PickupKind.W_RAIL, PickupKind.W_HOMING,
        };
        const string[,] DROP_TEXT = {
            { "BOMB",    "clears the screen" },
            { "SHIELD",  "6s invulnerable" },
            { "SPREAD",  "wide splash shots" },
            { "RAILGUN", "piercing heavy slug" },
            { "SEEKERS", "homing shots" },
        };

        public SettingsScreen (Game game) {
            base (game);
            stars = new Starfield ();
        }

        public override void handle_input () {
            int step = 0;
            if (nav_left ())  step -= 1;
            if (nav_right ()) step += 1;
            if (step != 0) {
                Settings.instance ().set_sfx_volume (
                    Settings.instance ().sfx_volume + step * 0.1f);
                Audio.instance ().play ("ui_move");   // audible at the new level
            }

            if (nav_confirm ()
                || Raylib.is_key_pressed (Raylib.KeyboardKey.ESCAPE)
                || Raylib.is_key_pressed (Raylib.KeyboardKey.BACKSPACE)) {
                Audio.instance ().play ("ui_select");
                game.goto_title ();
            }
        }

        public override void update (float dt) {
            stars.update (dt);
        }

        public override void draw () {
            stars.draw ();

            draw_text_centered ("SETTINGS", 40, 30, Palette.RAYWHITE);

            // ---- Sound-effects volume (adjustable) ----------------------
            float v = Settings.instance ().sfx_volume;
            draw_text_centered ("SOUND EFFECTS", 86, 16, Palette.SKYBLUE);

            int bar_w = 220;
            int bar_x = (Config.SCREEN_W - bar_w) / 2;
            int bar_y = 108;
            Raylib.draw_rectangle (bar_x, bar_y, bar_w, 12, Raylib.fade (Palette.WHITE, 0.15f));
            Raylib.draw_rectangle (bar_x, bar_y, (int) (bar_w * v), 12, Palette.LIME);
            Raylib.draw_rectangle_lines_ex ({ bar_x, bar_y, bar_w, 12 }, 1.0f,
                                            Raylib.fade (Palette.WHITE, 0.4f));
            draw_text_centered ("<  %d%%  >".printf ((int) Math.roundf (v * 100.0f)),
                                bar_y + 24, 16, Palette.LIGHTGRAY);

            cursor_y = 170;

            // ---- Controls ----------------------------------------------
            heading ("CONTROLS");
            for (int i = 0; i < KEYS.length[0]; i++)
                kv (KEYS[i, 0], KEYS[i, 1], Palette.LIGHTGRAY);

            // ---- Enemy drops legend ----------------------------------
            heading ("ENEMY DROPS");
            for (int i = 0; i < DROP_TEXT.length[0]; i++) {
                Raylib.draw_text (DROPS[i].glyph (), 54, cursor_y, 13, DROPS[i].colour ());
                kv (DROP_TEXT[i, 0], DROP_TEXT[i, 1], Palette.LIGHTGRAY, 72);
            }

            // ---- Enemies released per stage ------------------------
            heading ("ENEMIES PER STAGE  (x3 per level)");
            for (int lvl = 1; lvl <= Config.LEVELS; lvl++) {
                string counts = "%d     %d     %d".printf (
                    SectionScript.enemy_count (lvl, 1),
                    SectionScript.enemy_count (lvl, 2),
                    SectionScript.enemy_count (lvl, 3));
                kv (@"LEVEL $lvl", counts, Palette.LIGHTGRAY);
            }

            draw_text_centered ("left / right adjust volume  -  enter or esc to go back",
                                Config.SCREEN_H - 34, 13, Palette.GRAY);
        }

        void heading (string title) {
            cursor_y += 10;
            Raylib.draw_text (title, 54, cursor_y, 16, Palette.SKYBLUE);
            cursor_y += 22;
        }

        void kv (string label, string value, Raylib.Color label_col, int label_x = 54) {
            Raylib.draw_text (label, label_x, cursor_y, 13, label_col);
            int rw = Raylib.measure_text (value, 13);
            Raylib.draw_text (value, Config.SCREEN_W - 54 - rw, cursor_y, 13, Palette.GRAY);
            cursor_y += 19;
        }
    }
}
