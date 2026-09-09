/*
 * Explosion FX: a small pool of expanding puffs, drawn from the "explosion"
 * sprite sheet when the atlas is loaded, or as an expanding ring otherwise.
 */

namespace Starfall {

    public class Explosion : Object {
        public Raylib.Vector2 pos;
        public float size;
        public float t;
        public float life;
        public bool  active;
    }

    public class ExplosionPool : Object {
        public const int CAP = 48;
        public Explosion[] items;

        public ExplosionPool () {
            items = new Explosion[CAP];
            for (int i = 0; i < CAP; i++)
                items[i] = new Explosion ();
        }

        public void clear () {
            foreach (var e in items)
                e.active = false;
        }

        public void spawn (Raylib.Vector2 pos, float size) {
            foreach (var e in items) {
                if (e.active) continue;
                e.pos    = pos;
                e.size   = size;
                e.t      = 0.0f;
                e.life   = 0.45f;
                e.active = true;
                return;
            }
        }

        public void update (float dt) {
            foreach (var e in items) {
                if (!e.active) continue;
                e.t += dt;
                if (e.t >= e.life)
                    e.active = false;
            }
        }

        public void draw () {
            int nframes = Assets.instance ().frame_count ("explosion");
            foreach (var e in items) {
                if (!e.active) continue;
                float p = e.t / e.life;

                int frame = (int) (p * nframes);
                if (frame >= nframes) frame = nframes - 1;

                if (Assets.instance ().draw_sprite ("explosion", e.pos, e.size, 0.0f,
                                               Palette.WHITE, frame))
                    continue;

                // Fallback: bright core shrinking, ring expanding.
                float ring = e.size * (0.25f + 0.75f * p);
                Raylib.draw_circle_v (e.pos, ring * 0.5f,
                                      Raylib.fade (Palette.ORANGE, 1.0f - p));
                Raylib.draw_circle_v (e.pos, e.size * 0.30f * (1.0f - p),
                                      Raylib.fade (Palette.YELLOW, 1.0f - p * 0.5f));
            }
        }
    }
}
