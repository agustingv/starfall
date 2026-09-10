/*
 * Audio: loads the WAVs under assets/sounds (produced by tools/gen_sounds.py)
 * and plays them. Each effect gets a few raylib sound aliases, cycled so
 * rapid fire overlaps instead of cutting itself off.
 *
 * If the audio device isn't ready or the files aren't found the game runs
 * silent - every play () call is a no-op.
 *
 * Directory search: $STARFALL_SOUNDS, ./assets/sounds, <exe>/assets/sounds,
 * <exe>/../assets/sounds, <exe>/../share/starfall/sounds.
 */

namespace Starfall {

    public class Audio : Object {
        static Audio? _instance;

        public static Audio instance () {
            if (_instance == null)
                _instance = new Audio ();
            return _instance;
        }

        public bool loaded { get; private set; default = false; }

        // Global scale on every effect, driven by the settings screen.
        public float sfx_volume { get; set; default = 1.0f; }

        const int VOICES = 4;   // overlapping instances per effect

        const string[] NAMES = {
            "shot_player", "shot_enemy", "explosion_small", "explosion_big",
            "hit", "special", "powerup", "ui_move", "ui_select",
        };

        class Bank {
            public Raylib.Sound source;
            public Raylib.Sound[] voices;
            public int next;
        }

        HashTable<string, Bank> banks;

        Audio () {
            banks = new HashTable<string, Bank> (str_hash, str_equal);

            if (!Raylib.is_audio_device_ready ()) {
                message ("sound: audio device not ready; running silent");
                return;
            }

            string? dir = find_dir ();
            if (dir == null) {
                message ("sound: no wav folder found; running silent");
                return;
            }

            foreach (unowned string n in NAMES) {
                string path = Path.build_filename (dir, n + ".wav");
                if (!FileUtils.test (path, FileTest.EXISTS))
                    continue;

                var src = Raylib.load_sound (path);
                if (!Raylib.is_sound_valid (src))
                    continue;

                var bank = new Bank ();
                bank.source = src;
                bank.voices = new Raylib.Sound[VOICES];
                for (int i = 0; i < VOICES; i++)
                    bank.voices[i] = Raylib.load_sound_alias (src);
                banks.insert (n, bank);
            }

            loaded = banks.size () > 0;
            if (loaded)
                message ("sound: loaded %u effects from %s", banks.size (), dir);
        }

        static string? find_dir () {
            string[] candidates = {};

            string? env = Environment.get_variable ("STARFALL_SOUNDS");
            if (env != null)
                candidates += env;

            candidates += Path.build_filename ("assets", "sounds");

            unowned string exe = Raylib.get_application_directory ();
            candidates += Path.build_filename (exe, "assets", "sounds");
            candidates += Path.build_filename (exe, "..", "assets", "sounds");
            candidates += Path.build_filename (exe, "..", "share", "starfall", "sounds");

            foreach (unowned string c in candidates) {
                if (FileUtils.test (Path.build_filename (c, "shot_player.wav"), FileTest.EXISTS))
                    return c;
            }
            return null;
        }

        /*
         * Play `name`. `pitch_jitter` (0..1) randomises pitch by +-that fraction
         * so repeats don't sound machine-stamped; `volume` scales this instance.
         */
        public void play (string name, float pitch_jitter = 0.0f, float volume = 1.0f) {
            Bank? b = banks.lookup (name);
            if (b == null)
                return;

            Raylib.Sound v = b.voices[b.next];
            b.next = (b.next + 1) % b.voices.length;

            float pitch = 1.0f;
            if (pitch_jitter > 0.0f)
                pitch = 1.0f + (float) Random.double_range (-pitch_jitter, pitch_jitter);
            Raylib.set_sound_pitch (v, pitch);
            Raylib.set_sound_volume (v, volume * sfx_volume);
            Raylib.play_sound (v);
        }
    }
}
