/*
 * End-of-level boss. One parameterised craft reused for all five levels, with
 * hp / rate / palette scaled by level. It cycles through four fire patterns:
 *
 *   SPREAD   - a gentle downward fan (widens once past half health)
 *   SPIRAL   - two slow arms that rotate a little with every shot
 *   AIMED    - a short three-round burst pointed at the player
 *   MISSILES - two homing missiles, only once health drops below ~70%
 *
 * Fire cadence eases off as the fight goes on rather than ramping up, so the
 * encounter stays readable.
 */

namespace Starfall {

    public class Boss : Object {
        public Raylib.Vector2 pos;
        public float radius;
        public float hp;
        public float max_hp;
        public bool  active;

        int   level;
        float entering;   // > 0 while sliding in from the top
        float move_t;
        float fire_t;
        Raylib.Color tint;

        int   pattern;        // 0 spread, 1 spiral, 2 aimed, 3 missiles
        int   spiral_shots;   // shots emitted so far in the current spiral
        float spiral_ang;

        public void spawn (int level) {
            this.level        = level;
            this.active       = true;
            this.radius       = 46.0f;
            this.max_hp       = 40.0f + level * 30.0f;
            this.hp           = max_hp;
            this.pos          = { Config.SCREEN_W / 2.0f, -radius };
            this.entering     = 1.0f;
            this.move_t       = 0.0f;
            this.fire_t       = 1.8f;
            this.tint         = tint_for (level);
            this.pattern      = 0;
            this.spiral_shots = 0;
            this.spiral_ang   = 0.0f;
        }

        public bool hittable () {
            return active && entering <= 0.0f;
        }

        public void damage (float amount) {
            hp -= amount;
            if (hp <= 0.0f) {
                hp = 0.0f;
                active = false;
            }
        }

        public void update (float dt, BulletPool bullets, Player player) {
            if (entering > 0.0f) {
                pos.y += 55.0f * dt;
                if (pos.y >= 92.0f) {
                    pos.y = 92.0f;
                    entering = 0.0f;
                }
                return;
            }

            move_t += dt;
            float span = Config.SCREEN_W / 2.0f - radius - 12.0f;
            pos.x = Config.SCREEN_W / 2.0f + Math.sinf (move_t * 0.8f) * span;

            // Missiles home via BulletPool.update (shared with the enemy craft).

            fire_t -= dt;
            if (fire_t <= 0.0f)
                fire (bullets, player);
        }

        /* ---- Fire patterns -------------------------------------------------- */

        void fire (BulletPool bullets, Player player) {
            switch (pattern) {
                case 1:  fire_spiral (bullets);          break;
                case 2:  fire_aimed (bullets, player);   break;
                case 3:  fire_missiles (bullets, player); break;
                default: fire_spread (bullets);          break;
            }
        }

        void fire_spread (BulletPool bullets) {
            Audio.instance ().play ("shot_enemy", 0.05f, 0.75f);

            int wings = (hp / max_hp < 0.5f) ? 2 : 1;
            for (int i = -wings; i <= wings; i++) {
                float ang = 1.5708f + i * 0.30f;
                bullets.spawn ({ pos.x, pos.y + radius },
                               { Math.cosf (ang) * 130.0f, Math.sinf (ang) * 130.0f },
                               false, 5.0f, Palette.MAGENTA);
            }

            advance_pattern ();
            fire_t = recover (1.4f);
        }

        void fire_spiral (BulletPool bullets) {
            if (spiral_shots == 0)
                Audio.instance ().play ("shot_enemy", 0.04f, 0.95f);

            spiral_ang += 0.38f;
            for (int arm = 0; arm < 2; arm++) {
                float ang = spiral_ang + arm * 3.1415927f;
                bullets.spawn ({ pos.x, pos.y },
                               { Math.cosf (ang) * 120.0f, Math.sinf (ang) * 120.0f },
                               false, 5.0f, Palette.ORANGE);
            }

            spiral_shots++;
            if (spiral_shots >= 8) {
                advance_pattern ();
                fire_t = recover (1.1f);
            } else {
                fire_t = 0.14f;
            }
        }

        void fire_aimed (BulletPool bullets, Player player) {
            Audio.instance ().play ("shot_enemy", 0.05f, 0.7f);

            float bx, by;
            aim (player, out bx, out by);
            for (int i = -1; i <= 1; i++) {
                float c = Math.cosf (i * 0.18f);
                float s = Math.sinf (i * 0.18f);
                bullets.spawn ({ pos.x, pos.y + radius },
                               { (bx * c - by * s) * 165.0f, (bx * s + by * c) * 165.0f },
                               false, 5.0f, Palette.RED);
            }

            advance_pattern ();
            fire_t = recover (1.2f);
        }

        void fire_missiles (BulletPool bullets, Player player) {
            Audio.instance ().play ("shot_enemy", 0.05f, 0.45f);

            float bx, by;
            aim (player, out bx, out by);
            float base_ang = Math.atan2f (by, bx);
            for (int i = -1; i <= 1; i += 2) {
                float a = base_ang + i * 0.28f;
                var m = bullets.spawn ({ pos.x, pos.y + radius * 0.5f },
                                       { Math.cosf (a) * 115.0f, Math.sinf (a) * 115.0f },
                                       false, 6.0f, Palette.ORANGE);
                if (m != null) {
                    m.missile    = true;
                    m.speed      = 122.0f;
                    m.turn       = 1.9f;
                    m.steer_time = 1.7f;
                }
            }

            advance_pattern ();
            fire_t = recover (1.5f);
        }

        /* Pick the next pattern. Missiles only join in once the boss is under
         * ~70% health; the aimed burst is held back while it's nearly full. */
        void advance_pattern () {
            pattern = (pattern + 1) % 4;
            float frac = hp / max_hp;
            if (pattern == 3 && frac > 0.70f) pattern = 0;
            if (pattern == 2 && frac > 0.88f) pattern = 0;
            spiral_shots = 0;
        }

        /* Recovery delay between volleys: close to `base` at full health,
         * easing down to about 62% of it as health runs out. */
        float recover (float at_full) {
            float frac = clampf (hp / max_hp, 0.0f, 1.0f);
            return clampf (at_full * (0.62f + 0.38f * frac), 0.42f, at_full);
        }

        void aim (Player player, out float bx, out float by) {
            float dx = player.pos.x - pos.x;
            float dy = player.pos.y - pos.y;
            float len = Math.sqrtf (dx * dx + dy * dy);
            if (len < 0.001f) len = 1.0f;
            bx = dx / len;
            by = dy / len;
        }

        /* ---- Draw --------------------------------------------------------- */

        public void draw () {
            if (Assets.instance ().draw_sprite (@"boss_$(level)", pos, radius * 2.6f, 0.0f,
                                           Palette.WHITE))
                return;

            Raylib.draw_circle_v (pos, radius, tint);
            Raylib.draw_circle_v (pos, radius * 0.62f, Raylib.fade (Palette.BLACK, 0.35f));
            Raylib.draw_circle_v (pos, radius * 0.30f, (hp / max_hp > 0.5f) ? Palette.MAGENTA : Palette.RED);
        }

        public void draw_health_bar () {
            if (!hittable ()) return;
            int x = 20;
            int y = 40;
            int w = Config.SCREEN_W - 40;
            float frac = clampf (hp / max_hp, 0.0f, 1.0f);
            Raylib.draw_rectangle (x, y, w, 10, Raylib.fade (Palette.WHITE, 0.15f));
            Raylib.draw_rectangle (x, y, (int) (w * frac), 10, Palette.RED);
            Raylib.draw_rectangle_lines_ex ({ x, y, w, 10 }, 1.0f, Raylib.fade (Palette.WHITE, 0.4f));
        }

        static Raylib.Color tint_for (int level) {
            switch (level) {
                case 1:  return Palette.SKYBLUE;
                case 2:  return Palette.ORANGE;
                case 3:  return Palette.RED;
                case 4:  return Palette.LIGHTGRAY;
                default: return Palette.MAGENTA;
            }
        }
    }
}
