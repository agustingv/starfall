/*
 * Settings: a tiny persisted preferences store (currently just the
 * sound-effects volume). Saved as key=value lines under:
 *
 *   $STARFALL_SETTINGS
 *   $XDG_CONFIG_HOME/starfall/settings.txt   (normally ~/.config/starfall/...)
 *
 * If the file is missing or unreadable the defaults are used and the game
 * still runs.
 */

namespace Starfall {

    public class Settings : Object {
        static Settings? _instance;

        public static Settings instance () {
            if (_instance == null)
                _instance = new Settings ();
            return _instance;
        }

        float _sfx_volume = 1.0f;
        public float sfx_volume { get { return _sfx_volume; } }

        Settings () {
            load ();
            Audio.instance ().sfx_volume = _sfx_volume;
        }

        public void set_sfx_volume (float v) {
            float nv = clampf (v, 0.0f, 1.0f);
            if (nv == _sfx_volume)
                return;
            _sfx_volume = nv;
            Audio.instance ().sfx_volume = nv;
            save ();
        }

        /* ---- persistence -------------------------------------------------- */

        string path () {
            string? env = Environment.get_variable ("STARFALL_SETTINGS");
            if (env != null)
                return env;
            return Path.build_filename (Environment.get_user_config_dir (),
                                        "starfall", "settings.txt");
        }

        void load () {
            string body;
            try {
                FileUtils.get_contents (path (), out body);
            } catch (FileError e) {
                return;
            }

            foreach (unowned string raw in body.split ("\n")) {
                string line = raw.strip ();
                if (line == "" || line.has_prefix ("#"))
                    continue;

                string[] kv = line.split ("=", 2);
                if (kv.length != 2)
                    continue;

                string key = kv[0].strip ();
                string val = kv[1].strip ();
                if (key == "sfx_volume")
                    _sfx_volume = clampf (int.parse (val) / 100.0f, 0.0f, 1.0f);
            }
        }

        void save () {
            string p = path ();
            DirUtils.create_with_parents (Path.get_dirname (p), 0755);

            var sb = new StringBuilder ("# Starfall settings\n");
            sb.append_printf ("sfx_volume=%d\n", (int) Math.roundf (sfx_volume * 100.0f));

            try {
                FileUtils.set_contents (p, sb.str);
            } catch (FileError e) {
                warning ("settings: cannot write %s: %s", p, e.message);
            }
        }
    }
}
