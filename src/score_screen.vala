/*
 * ScoreScreen: the high-score table on its own, reached from the title menu.
 */

namespace Starfall {

    public class ScoreScreen : Screen {
        Starfield stars;

        public ScoreScreen (Game game) {
            base (game);
            stars = new Starfield ();
        }

        public override void handle_input () {
            if (nav_confirm ())
                game.goto_title ();
        }

        public override void update (float dt) {
            stars.update (dt);
        }

        public override void draw () {
            stars.draw ();
            HighScores.instance ().draw_table (-1);
            draw_text_centered ("enter to go back", Config.SCREEN_H - 58, 16, Palette.LIGHTGRAY);
        }
    }
}
