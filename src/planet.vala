/*
 * Backdrop planet. One distant world per level - Titan, Jupiter, Mars, the
 * Moon, Earth - drifting slowly down the screen behind the starfield, far
 * slower than any star layer so it reads as very far away. It wraps back above
 * the screen with a long gap once it clears the bottom, so it drifts past at
 * most once or twice per level.
 */

namespace Starfall {

    public class Planet : Object {
        int   level = 1;
        float x;
        float y;
        float size;     // on-screen height, px
        float speed;    // downward drift, px/s

        const float GAP = 820.0f;   // travel above the screen before it re-enters

        public void set_level (int level) {
            this.level = int.max (1, int.min (Config.LEVELS, level));
            switch (this.level) {
                case 1:  x = Config.SCREEN_W * 0.70f; size = 210.0f; speed =  8.0f; break;
                case 2:  x = Config.SCREEN_W * 0.32f; size = 264.0f; speed =  7.0f; break;
                case 3:  x = Config.SCREEN_W * 0.74f; size = 184.0f; speed = 10.0f; break;
                case 4:  x = Config.SCREEN_W * 0.26f; size = 150.0f; speed = 12.0f; break;
                default: x = Config.SCREEN_W * 0.58f; size = 300.0f; speed =  6.0f; break;
            }
            y = -size * 0.5f - 40.0f;
        }

        public void update (float dt) {
            y += speed * dt;
            if (y - size * 0.5f > Config.SCREEN_H)
                y = -size * 0.5f - GAP;
        }

        public void draw () {
            if (Assets.instance ().draw_sprite (@"planet_$(level)", { x, y }, size, 0.0f,
                                                Raylib.fade (Palette.WHITE, 0.92f)))
                return;

            // Fallback when the atlas is missing: a dim tinted disc.
            Raylib.draw_circle_v ({ x, y }, size * 0.5f, Raylib.fade (tint_for (level), 0.5f));
        }

        static Raylib.Color tint_for (int level) {
            switch (level) {
                case 1:  return Palette.ORANGE;
                case 2:  return Palette.LIGHTGRAY;
                case 3:  return Palette.RED;
                case 4:  return Palette.GRAY;
                default: return Palette.SKYBLUE;
            }
        }
    }
}
