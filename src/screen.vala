/*
 * Screen: one self-contained mode of the app (title, gameplay, ...). Game owns
 * exactly one at a time and forwards the fixed-step update and the draw call to
 * it. Screens ask Game for transitions (start_new_game / goto_title /
 * request_quit).
 */

namespace Starfall {

    public abstract class Screen : Object {
        protected unowned Game game;

        protected Screen (Game game) {
            this.game = game;
        }

        public virtual void on_enter () {}

        /*
         * Edge-triggered input (menus, pause, confirm). Called once per rendered
         * frame - NOT from the fixed-step loop, where raylib's one-frame
         * is_key_pressed() edges would be missed most of the time.
         */
        public virtual void handle_input () {}

        /* Fixed-step simulation, called at Config.TICK. */
        public abstract void update (float dt);

        public abstract void draw ();

        /* ---- Shared menu navigation (keyboard + gamepad, edge-triggered) --- */

        protected static bool nav_up () {
            return Raylib.is_key_pressed (Raylib.KeyboardKey.UP)
                || Raylib.is_key_pressed (Raylib.KeyboardKey.W)
                || (Raylib.is_gamepad_available (0)
                    && Raylib.is_gamepad_button_pressed (0, Raylib.GamepadButton.LEFT_FACE_UP));
        }

        protected static bool nav_down () {
            return Raylib.is_key_pressed (Raylib.KeyboardKey.DOWN)
                || Raylib.is_key_pressed (Raylib.KeyboardKey.S)
                || (Raylib.is_gamepad_available (0)
                    && Raylib.is_gamepad_button_pressed (0, Raylib.GamepadButton.LEFT_FACE_DOWN));
        }

        protected static bool nav_confirm () {
            return Raylib.is_key_pressed (Raylib.KeyboardKey.ENTER)
                || Raylib.is_key_pressed (Raylib.KeyboardKey.SPACE)
                || (Raylib.is_gamepad_available (0)
                    && Raylib.is_gamepad_button_pressed (0, Raylib.GamepadButton.RIGHT_FACE_DOWN));
        }

        /* ---- Small drawing helpers ---------------------------------------- */

        public static void draw_text_centered (string text, int y, int size, Raylib.Color color) {
            int w = Raylib.measure_text (text, size);
            Raylib.draw_text (text, (Config.SCREEN_W - w) / 2, y, size, color);
        }

        protected static void draw_banner (string text) {
            int size = 34;
            int strip_y = Config.SCREEN_H / 2 - 34;
            Raylib.draw_rectangle (0, strip_y, Config.SCREEN_W, 68,
                                   Raylib.fade (Palette.BLACK, 0.55f));
            draw_text_centered (text, strip_y + 17, size, Palette.RAYWHITE);
        }

        protected static void draw_overlay (string title, string hint) {
            Raylib.draw_rectangle (0, 0, Config.SCREEN_W, Config.SCREEN_H,
                                   Raylib.fade (Palette.BLACK, 0.65f));
            draw_text_centered (title, Config.SCREEN_H / 2 - 40, 44, Palette.RAYWHITE);
            draw_text_centered (hint, Config.SCREEN_H / 2 + 18, 18, Palette.LIGHTGRAY);
        }
    }
}
