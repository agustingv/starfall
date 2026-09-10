/*
 * The player's ship: movement, a rate-limited cannon, lives, and a brief
 * spawn/hit invulnerability window.
 */

namespace Starfall {

    /* Front gun, swapped by weapon power-ups. BLASTER is the default a run
     * starts (and reverts to) with; the rest are timed. */
    public enum WeaponType {
        BLASTER,   // rapid single frontal shots
        SPREAD,    // battery: a fan of splash pellets
        RAIL,      // railgun: fast piercing slug, heavy damage
        HOMING;    // seekers: guided shots that chase the nearest enemy

        public string label () {
            switch (this) {
                case SPREAD: return "SPREAD BATTERY";
                case RAIL:   return "RAILGUN";
                case HOMING: return "SEEKERS";
                default:     return "BLASTER";
            }
        }
    }

    public class Player : Object {
        public const int   SPECIAL_MAX = 2;
        public const float WEAPON_TIME = 15.0f;
        public const float SHIELD_TIME = 6.0f;

        public Raylib.Vector2 pos;
        public float radius = 12.0f;
        public int   lives;
        public bool  alive;
        public int   special_charges;

        public WeaponType weapon { get; private set; default = WeaponType.BLASTER; }

        float speed;
        float fire_interval;
        float fire_cooldown;
        float invuln_timer;
        float weapon_timer;
        float shield_timer;

        public bool invulnerable {
            get { return invuln_timer > 0.0f; }
        }

        /* True whenever incoming fire should be ignored - spawn/hit i-frames,
         * the bomb's immunity, or an active shield power-up. */
        public bool damage_immune {
            get { return invuln_timer > 0.0f || shield_timer > 0.0f; }
        }

        public bool  shielded    { get { return shield_timer > 0.0f; } }
        public float weapon_frac { get { return clampf (weapon_timer / WEAPON_TIME, 0.0f, 1.0f); } }
        public float shield_frac { get { return clampf (shield_timer / SHIELD_TIME, 0.0f, 1.0f); } }

        // Dev-only "can't be killed" toggle: seeded from $STARFALL_GODMODE at
        // reset, flipped in-game with F10. Purely for walking the campaign.
        public bool godmode;

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
            weapon          = WeaponType.BLASTER;
            weapon_timer    = 0.0f;
            shield_timer    = 0.0f;

            string? g = Environment.get_variable ("STARFALL_GODMODE");
            godmode = (g != null && g != "" && g != "0" && g.down () != "false");
        }

        /* Power-up pickups. A weapon refreshes its timer if grabbed again. */
        public void give_weapon (WeaponType w) {
            weapon       = w;
            weapon_timer = WEAPON_TIME;
        }

        public void grant_shield () {
            shield_timer = SHIELD_TIME;
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
            if (invuln_timer  > 0.0f) invuln_timer  -= dt;
            if (shield_timer  > 0.0f) shield_timer  -= dt;
            if (weapon_timer  > 0.0f) {
                weapon_timer -= dt;
                if (weapon_timer <= 0.0f) weapon = WeaponType.BLASTER;
            }

            pos.x = clampf (pos.x + input.move_x * speed * dt, radius, Config.SCREEN_W - radius);
            pos.y = clampf (pos.y + input.move_y * speed * dt, radius, Config.SCREEN_H - radius);

            fire_cooldown -= dt;
            if (input.firing && fire_cooldown <= 0.0f)
                fire (bullets);
        }

        void fire (BulletPool bullets) {
            float mx = pos.x;
            float my = pos.y - radius - 4.0f;

            switch (weapon) {
                case WeaponType.SPREAD:
                    fire_cooldown = 0.20f;
                    for (int i = -2; i <= 2; i++) {
                        float ang = -1.5708f + i * 0.16f;
                        var b = bullets.spawn ({ mx, my },
                            { Math.cosf (ang) * 430.0f, Math.sinf (ang) * 430.0f },
                            true, 5.0f, Palette.ORANGE);
                        if (b != null) b.aoe = 26.0f;
                    }
                    Audio.instance ().play ("shot_player", 0.06f, 0.7f);
                    break;

                case WeaponType.RAIL:
                    fire_cooldown = 0.42f;
                    var r = bullets.spawn ({ mx, my }, { 0.0f, -1150.0f },
                                           true, 4.0f, Palette.SKYBLUE);
                    if (r != null) { r.pierce = 6; r.damage = 3.0f; }
                    Audio.instance ().play ("shot_player", 0.05f, 1.35f);
                    break;

                case WeaponType.HOMING:
                    fire_cooldown = 0.22f;
                    for (int i = -1; i <= 1; i += 2) {
                        var m = bullets.spawn ({ mx + i * 8.0f, my },
                            { i * 70.0f, -300.0f }, true, 4.0f, Palette.LIME);
                        if (m != null) {
                            m.missile     = true;
                            m.speed       = 360.0f;
                            m.turn        = 6.0f;
                            m.steer_time  = 3.0f;
                        }
                    }
                    Audio.instance ().play ("shot_player", 0.06f, 0.8f);
                    break;

                default: // BLASTER
                    fire_cooldown = fire_interval;
                    bullets.spawn ({ mx, my }, { 0.0f, -520.0f }, true, 3.0f, Palette.YELLOW);
                    Audio.instance ().play ("shot_player", 0.06f, 0.9f);
                    break;
            }
        }

        public void hit () {
            if (godmode || damage_immune) return;
            lives -= 1;
            invuln_timer = 2.0f;
            weapon       = WeaponType.BLASTER;   // lose the power-up gun on death
            weapon_timer = 0.0f;
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
            // Shield bubble sits behind everything and stays visible through blinks.
            if (shield_timer > 0.0f) {
                float pulse = 0.85f + 0.15f * Math.sinf ((float) Raylib.get_time () * 8.0f);
                float a = clampf (shield_frac + 0.15f, 0.0f, 1.0f);
                Raylib.draw_circle_v (pos, radius * 2.4f * pulse,
                                      Raylib.fade (Palette.SKYBLUE, 0.10f * a));
                Raylib.draw_circle_v (pos, radius * 2.0f * pulse,
                                      Raylib.fade (Palette.SKYBLUE, 0.14f * a));
            }

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
