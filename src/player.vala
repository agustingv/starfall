/*
 * The player's ship: movement, a rate-limited cannon, lives, and a brief
 * spawn/hit invulnerability window.
 */

namespace Starfall {

    public class Player : Object {
        public const int SPECIAL_MAX = 2;

        public Raylib.Vector2 pos;
        public float radius = 12.0f;
        public int   lives;
        public bool  alive;
        public int   special_charges;

        float speed;
        float fire_interval;
        float fire_cooldown;
        float invuln_timer;

        public bool invulnerable {
            get { return invuln_timer > 0.0f; }
        }

        public Player () {
            reset ();
        }

        public void reset () {
            pos             = { Config.SCREEN_W / 2.0f, Config.SCREEN_H - 90.0f };
            lives           = 3;
            alive           = true;
            special_charges = SPECIAL_MAX;
            speed           = 260.0f;
            fire_interval   = 0.14f;
            fire_cooldown   = 0.0f;
            invuln_timer    = 1.5f;
        }

        /* Spend a special-weapon charge. Grants 3s of immunity. */
        public bool use_special () {
            if (special_charges <= 0)
                return false;
            special_charges--;
            invuln_timer = 3.0f;
            return true;
        }

        public void add_special_charge () {
            if (special_charges < SPECIAL_MAX)
                special_charges++;
        }

        /* Merge keyboard + gamepad into a single normalised intent. */
        public static Input read_input () {
            Input i = { 0.0f, 0.0f, false };

            if (Raylib.is_key_down (Raylib.KeyboardKey.LEFT)  || Raylib.is_key_down (Raylib.KeyboardKey.A)) i.move_x -= 1.0f;
            if (Raylib.is_key_down (Raylib.KeyboardKey.RIGHT) || Raylib.is_key_down (Raylib.KeyboardKey.D)) i.move_x += 1.0f;
            if (Raylib.is_key_down (Raylib.KeyboardKey.UP)    || Raylib.is_key_down (Raylib.KeyboardKey.W)) i.move_y -= 1.0f;
            if (Raylib.is_key_down (Raylib.KeyboardKey.DOWN)  || Raylib.is_key_down (Raylib.KeyboardKey.S)) i.move_y += 1.0f;
            i.firing = Raylib.is_key_down (Raylib.KeyboardKey.SPACE);

            if (Raylib.is_gamepad_available (0)) {
                float ax = Raylib.get_gamepad_axis_movement (0, Raylib.GamepadAxis.LEFT_X);
                float ay = Raylib.get_gamepad_axis_movement (0, Raylib.GamepadAxis.LEFT_Y);
                if (absf (ax) > 0.2f) i.move_x += ax;
                if (absf (ay) > 0.2f) i.move_y += ay;

                if (Raylib.is_gamepad_button_down (0, Raylib.GamepadButton.LEFT_FACE_LEFT))  i.move_x -= 1.0f;
                if (Raylib.is_gamepad_button_down (0, Raylib.GamepadButton.LEFT_FACE_RIGHT)) i.move_x += 1.0f;
                if (Raylib.is_gamepad_button_down (0, Raylib.GamepadButton.LEFT_FACE_UP))    i.move_y -= 1.0f;
                if (Raylib.is_gamepad_button_down (0, Raylib.GamepadButton.LEFT_FACE_DOWN))  i.move_y += 1.0f;
                if (Raylib.is_gamepad_button_down (0, Raylib.GamepadButton.RIGHT_FACE_DOWN)) i.firing = true;
            }

            i.move_x = clampf (i.move_x, -1.0f, 1.0f);
            i.move_y = clampf (i.move_y, -1.0f, 1.0f);
            return i;
        }

        public void update (float dt, Input input, BulletPool bullets) {
            if (invuln_timer > 0.0f) invuln_timer -= dt;

            pos.x = clampf (pos.x + input.move_x * speed * dt, radius, Config.SCREEN_W - radius);
            pos.y = clampf (pos.y + input.move_y * speed * dt, radius, Config.SCREEN_H - radius);

            fire_cooldown -= dt;
            if (input.firing && fire_cooldown <= 0.0f) {
                fire_cooldown = fire_interval;
                bullets.spawn ({ pos.x, pos.y - radius - 4.0f }, { 0.0f, -520.0f },
                               true, 3.0f, Palette.YELLOW);
                Audio.instance ().play ("shot_player", 0.06f, 0.9f);
            }
        }

        public void hit () {
            if (invulnerable) return;
            lives -= 1;
            invuln_timer = 2.0f;
            pos = { Config.SCREEN_W / 2.0f, Config.SCREEN_H - 90.0f };
            if (lives <= 0) alive = false;
        }

        /* Reposition between levels / boss intros without touching lives. */
        public void recenter () {
            pos = { Config.SCREEN_W / 2.0f, Config.SCREEN_H - 90.0f };
            fire_cooldown = 0.0f;
            invuln_timer = 1.5f;
        }

        public void draw () {
            // Blink while invulnerable.
            if (invulnerable && ((int) (Raylib.get_time () * 20.0)) % 2 == 0)
                return;

            float r = radius;

            // Engine flame first, so the hull sits on top of it.
            float flick = (Raylib.get_time () * 60.0) % 2 < 1 ? 1.0f : 0.6f;
            Raylib.draw_triangle ({ pos.x - r * 0.4f, pos.y + r },
                                  { pos.x, pos.y + r + 10.0f * flick },
                                  { pos.x + r * 0.4f, pos.y + r },
                                  Palette.ORANGE);

            if (Assets.instance ().draw_sprite ("player", pos, r * 3.1f, 0.0f, Palette.WHITE))
                return;

            Raylib.Vector2 tip   = { pos.x,       pos.y - r * 1.4f };
            Raylib.Vector2 left  = { pos.x - r,   pos.y + r };
            Raylib.Vector2 right = { pos.x + r,   pos.y + r };

            Raylib.draw_triangle (tip, left, right, Palette.SKYBLUE);
            Raylib.draw_triangle ({ pos.x - r * 1.5f, pos.y + r * 0.8f }, left,
                                  { pos.x - r * 0.3f, pos.y + r * 0.2f }, Palette.WHITE);
            Raylib.draw_triangle ({ pos.x + r * 1.5f, pos.y + r * 0.8f },
                                  { pos.x + r * 0.3f, pos.y + r * 0.2f }, right, Palette.WHITE);
            Raylib.draw_circle_v ({ pos.x, pos.y }, r * 0.35f, Palette.YELLOW);
        }
    }
}
