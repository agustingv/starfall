/*
 * Parallax starfield backdrop. Three depth layers scroll downward at different
 * speeds to sell the sense of the ship flying "up".
 */

namespace Starfall {

    struct Star {
        float x;
        float y;
        float speed;
        float size;
        uint8 bright;
    }

    public class Starfield : Object {
        Star[] stars;

        const int COUNT = 150;

        public Starfield () {
            Raylib.set_random_seed (20250909);
            stars = new Star[COUNT];
            for (int i = 0; i < COUNT; i++) {
                int layer = Raylib.get_random_value (0, 2);
                stars[i].x      = Raylib.get_random_value (0, Config.SCREEN_W);
                stars[i].y      = Raylib.get_random_value (0, Config.SCREEN_H);
                stars[i].speed  = 25.0f + layer * 55.0f + Raylib.get_random_value (0, 18);
                stars[i].size   = (layer == 2) ? 2.0f : 1.0f;
                stars[i].bright = (uint8) (80 + layer * 60);
            }
        }

        public void update (float dt) {
            for (int i = 0; i < COUNT; i++) {
                stars[i].y += stars[i].speed * dt;
                if (stars[i].y > Config.SCREEN_H) {
                    stars[i].y = 0.0f;
                    stars[i].x = Raylib.get_random_value (0, Config.SCREEN_W);
                }
            }
        }

        public void draw () {
            foreach (var s in stars) {
                Raylib.Color c = { s.bright, s.bright, (uint8) (s.bright + 30), 255 };
                Raylib.draw_rectangle_v ({ s.x, s.y }, { s.size, s.size }, c);
            }
        }
    }
}
