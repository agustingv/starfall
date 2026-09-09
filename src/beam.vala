/*
 * Enemy laser beam - the SENTINEL's weapon. Two stages: a thin charging line
 * that still tracks the muzzle, then a thick beam locked to the angle it had
 * when it fired. Only the firing stage hurts the player. Pooled.
 */

namespace Starfall {

    public class EnemyBeam : Object {
        public bool active;

        const float CHARGE = 0.70f;   // telegraph, no damage
        const float FIRE   = 0.50f;   // beam live
        const float LEN    = 900.0f;
        const float HALF_W = 7.0f;    // damage half-width while firing

        unowned Enemy? src;
        Raylib.Vector2 origin;
        float angle;
        float charge_t;
        float fire_t;

        public void reset (Enemy e, Player player) {
            src      = e;
            origin   = e.pos;
            float a  = Math.atan2f (player.pos.y - e.pos.y, player.pos.x - e.pos.x);
            angle    = clampf (a, 0.55f, 3.1415927f - 0.55f);  // keep it pointing down
            charge_t = CHARGE;
            fire_t   = FIRE;
            active   = true;
        }

        bool charging () { return charge_t > 0.0f; }
        bool firing ()   { return charge_t <= 0.0f && fire_t > 0.0f; }

        public void update (float dt) {
            if (src != null && src.active && charging ())
                origin = src.pos;                 // follow the muzzle until it fires

            if (charging ()) {
                charge_t -= dt;
                if (charge_t <= 0.0f)
                    Audio.instance ().play ("special", 0.04f, 1.0f);
            } else {
                fire_t -= dt;
                if (fire_t <= 0.0f) {
                    active = false;
                    src    = null;
                }
            }
        }

        public bool hits (Player p) {
            if (!firing ()) return false;
            float ex = origin.x + Math.cosf (angle) * LEN;
            float ey = origin.y + Math.sinf (angle) * LEN;
            return seg_dist (p.pos.x, p.pos.y, origin.x, origin.y, ex, ey)
                   <= p.radius + HALF_W;
        }

        static float seg_dist (float px, float py, float ax, float ay, float bx, float by) {
            float dx = bx - ax;
            float dy = by - ay;
            float len2 = dx * dx + dy * dy;
            float t = (len2 > 0.0001f) ? ((px - ax) * dx + (py - ay) * dy) / len2 : 0.0f;
            t = clampf (t, 0.0f, 1.0f);
            float cx = ax + t * dx;
            float cy = ay + t * dy;
            return Math.sqrtf ((px - cx) * (px - cx) + (py - cy) * (py - cy));
        }

        public void draw () {
            Raylib.Vector2 end = {
                origin.x + Math.cosf (angle) * LEN,
                origin.y + Math.sinf (angle) * LEN
            };

            if (charging ()) {
                float k = 1.0f - charge_t / CHARGE;
                Raylib.draw_line_ex (origin, end, 1.0f + 2.0f * k,
                                     Raylib.fade (Palette.YELLOW, 0.20f + 0.45f * k));
                Raylib.draw_circle_v (origin, 3.0f + 4.0f * k,
                                      Raylib.fade (Palette.RAYWHITE, 0.2f + 0.6f * k));
                return;
            }

            float flick = 0.82f + 0.18f * Math.sinf ((float) Raylib.get_time () * 55.0f);
            Raylib.draw_line_ex (origin, end, HALF_W * 2.0f * flick,
                                 Raylib.fade (Palette.RED, 0.55f));
            Raylib.draw_line_ex (origin, end, HALF_W * 1.1f * flick,
                                 Raylib.fade (Palette.ORANGE, 0.85f));
            Raylib.draw_line_ex (origin, end, HALF_W * 0.45f, Palette.RAYWHITE);
            Raylib.draw_circle_v (origin, HALF_W * 1.6f, Raylib.fade (Palette.RAYWHITE, 0.9f));
        }
    }

    public class EnemyBeamPool : Object {
        public const int CAP = 12;
        public EnemyBeam[] items;

        public EnemyBeamPool () {
            items = new EnemyBeam[CAP];
            for (int i = 0; i < CAP; i++)
                items[i] = new EnemyBeam ();
        }

        public void clear () {
            foreach (var b in items)
                b.active = false;
        }

        public void spawn (Enemy e, Player player) {
            foreach (var b in items) {
                if (b.active) continue;
                b.reset (e, player);
                return;
            }
        }

        public void update (float dt) {
            foreach (var b in items)
                if (b.active) b.update (dt);
        }

        public bool strike (Player player) {
            foreach (var b in items)
                if (b.active && b.hits (player)) return true;
            return false;
        }

        public void draw () {
            foreach (var b in items)
                if (b.active) b.draw ();
        }
    }
}
