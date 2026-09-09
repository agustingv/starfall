/*
 * HighScores: the top-10 table, persisted to a plain text file between runs.
 *
 *   $STARFALL_SCORES                         (override, mainly for testing)
 *   $XDG_DATA_HOME/starfall/highscores.txt   (normally ~/.local/share/...)
 *
 * File format, one entry per line:  INITIALS SCORE LEVEL
 * A fresh install is seeded with placeholder scores so there's something to
 * beat and the table is never empty.
 */

namespace Starfall {

    public class ScoreEntry : Object {
        public string initials;
        public int    score;
        public int    level;

        public ScoreEntry (string initials, int score, int level) {
            this.initials = initials;
            this.score    = score;
            this.level    = level;
        }
    }

    public class HighScores : Object {
        static HighScores? _instance;

        public static HighScores instance () {
            if (_instance == null)
                _instance = new HighScores ();
            return _instance;
        }

        public const int CAP = 10;

        public ScoreEntry[] entries;   // score-descending, at most CAP

        HighScores () {
            entries = {};
            if (!load ())
                seed_defaults ();
        }

        /* ---- queries -------------------------------------------------- */

        public bool qualifies (int score) {
            if (score <= 0)
                return false;
            return entries.length < CAP || score > entries[entries.length - 1].score;
        }

        public int rank_for (int score) {
            int r = 0;
            while (r < entries.length && entries[r].score >= score)
                r++;
            return r + 1;   // 1-based
        }

        /* Insert, persist, and return the row index it landed at (-1 if it
         * fell off the bottom). */
        public int add (string initials, int score, int level) {
            var added = new ScoreEntry (sanitize (initials), score, level);
            var list = entries;
            list += added;
            sort_clamp (ref list);
            entries = list;
            save ();

            for (int i = 0; i < entries.length; i++)
                if (entries[i] == added)
                    return i;
            return -1;
        }

        /* ---- drawing ----------------------------------------------------- */

        public void draw_table (int highlight) {
            Screen.draw_text_centered ("HIGH SCORES", 64, 38, Palette.RAYWHITE);

            int y = 138;
            for (int i = 0; i < entries.length; i++) {
                var e = entries[i];

                Raylib.Color col = (i < 3) ? Palette.SKYBLUE : Palette.LIGHTGRAY;
                if (i == highlight) {
                    col = (((int) (Raylib.get_time () * 3.0)) % 2 == 0)
                        ? Palette.YELLOW : Palette.WHITE;
                }

                Raylib.draw_text ("%2d".printf (i + 1), 66, y, 22, col);
                Raylib.draw_text (e.initials, 128, y, 22, col);

                string sc = "%08d".printf (e.score);
                int sw = Raylib.measure_text (sc, 22);
                Raylib.draw_text (sc, Config.SCREEN_W - 150 - sw, y, 22, col);
                Raylib.draw_text ("L%d".printf (e.level), Config.SCREEN_W - 118, y, 22, col);

                y += 42;
            }
        }

        /* ---- persistence -------------------------------------------------- */

        string path () {
            string? env = Environment.get_variable ("STARFALL_SCORES");
            if (env != null)
                return env;
            return Path.build_filename (Environment.get_user_data_dir (),
                                        "starfall", "highscores.txt");
        }

        bool load () {
            string body;
            try {
                FileUtils.get_contents (path (), out body);
            } catch (FileError e) {
                return false;
            }

            ScoreEntry[] list = {};
            foreach (unowned string raw in body.split ("\n")) {
                string line = raw.strip ();
                if (line == "" || line.has_prefix ("#"))
                    continue;
                string[] f = Regex.split_simple ("\\s+", line);
                if (f.length < 2)
                    continue;
                int sc = int.parse (f[1]);
                if (sc <= 0)
                    continue;
                int lv = (f.length >= 3) ? int.parse (f[2]) : 1;
                list += new ScoreEntry (sanitize (f[0]), sc, int.max (1, lv));
            }

            if (list.length == 0)
                return false;
            sort_clamp (ref list);
            entries = list;
            return true;
        }

        void save () {
            var sb = new StringBuilder ("# Starfall high scores  --  INITIALS SCORE LEVEL\n");
            foreach (var e in entries)
                sb.append_printf ("%s %d %d\n", e.initials, e.score, e.level);

            string p = path ();
            DirUtils.create_with_parents (Path.get_dirname (p), 0755);
            try {
                FileUtils.set_contents (p, sb.str);
            } catch (FileError e) {
                warning ("scores: cannot write %s: %s", p, e.message);
            }
        }

        void seed_defaults () {
            string[] names = { "ACE", "VEX", "ZOE", "KAI", "NYX",
                               "ORB", "RAY", "JET", "LUX", "IVY" };
            ScoreEntry[] list = {};
            int sc = 12000;
            foreach (unowned string n in names) {
                list += new ScoreEntry (n, sc, 1);
                sc -= 1100;
            }
            entries = list;
            save ();
        }

        /* ---- helpers ------------------------------------------------------ */

        static string sanitize (string s) {
            string u = s.up ();
            var sb = new StringBuilder ();
            for (int i = 0; i < u.length && sb.len < 3; i++) {
                if (u[i] >= 'A' && u[i] <= 'Z')
                    sb.append_c (u[i]);
            }
            while (sb.len < 3)
                sb.append_c ('A');
            return sb.str;
        }

        static void sort_clamp (ref ScoreEntry[] list) {
            for (int i = 0; i < list.length; i++)
                for (int j = i + 1; j < list.length; j++)
                    if (list[j].score > list[i].score) {
                        var t = list[i];
                        list[i] = list[j];
                        list[j] = t;
                    }
            if (list.length > CAP)
                list.resize (CAP);
        }
    }
}
