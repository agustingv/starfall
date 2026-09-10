/*
 * Title screen: the story hook, a drifting starfield, and a Play / Exit menu.
 */

namespace Starfall {

    public class TitleScreen : Screen {
        Starfield stars;
        int   selection = 0;
        float t = 0.0f;

        const string[] OPTIONS = { "PLAY", "SCORES", "SETTINGS", "EXIT" };

        const string[] STORY = {
            "The Andromedans crossed the void and took the Earth.",
            "",
            "From the Titan base, the last squadrons scramble",
            "and burn sunward - five embattled worlds between",
            "them and home.",
        };

        public TitleScreen (Game game) {
            base (game);
            stars = new Starfield ();
        }

        public override void handle_input () {
            int prev = selection;
            if (nav_up ())   selection--;
            if (nav_down ()) selection++;
            selection = (selection + OPTIONS.length) % OPTIONS.length;
            if (selection != prev)
                Audio.instance ().play ("ui_move");

            if (nav_confirm ()) {
                Audio.instance ().play ("ui_select");
                switch (selection) {
                    case 0:  game.start_new_game (); break;
                    case 1:  game.goto_scores ();    break;
                    case 2:  game.goto_settings ();  break;
                    default: game.request_quit ();   break;
                }
            }
        }

        public override void update (float dt) {
            t += dt;
            stars.update (dt);
        }

        public override void draw () {
            stars.draw ();

            draw_text_centered ("STARFALL", 96, 64, Palette.RAYWHITE);
            draw_text_centered ("liberation of earth", 168, 18, Palette.SKYBLUE);

            float bob = Math.sinf (t * 2.0f) * 5.0f;
            Assets.instance ().draw_sprite ("player", { Config.SCREEN_W / 2.0f, 216.0f + bob },
                                       70.0f, 0.0f, Palette.WHITE);

            int y = 268;
            foreach (unowned string line in STORY) {
                draw_text_centered (line, y, 16, Palette.LIGHTGRAY);
                y += 26;
            }

            int menu_y = 452;
            for (int i = 0; i < OPTIONS.length; i++) {
                bool sel = (i == selection);
                int size = sel ? 30 : 26;
                var color = sel ? Palette.YELLOW : Palette.LIGHTGRAY;
                string label = sel ? @"> $(OPTIONS[i])  <" : OPTIONS[i];
                draw_text_centered (label, menu_y, size, color);
                menu_y += 48;
            }

            if (((int) (t * 2.0)) % 2 == 0)
                draw_text_centered ("arrows to choose  -  enter to confirm",
                                    Config.SCREEN_H - 60, 14, Palette.GRAY);
        }
    }
}
