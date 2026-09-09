/*
 * Assets: loads assets/sprites/atlas.png + atlas.txt (produced by
 * tools/gen_sprites.py) and blits named regions. If the atlas can't be found
 * the game still runs - every draw() has a primitive fallback, and
 * draw_sprite() just returns false.
 *
 * Search order for the sprites directory:
 *   $STARFALL_ASSETS
 *   ./assets/sprites               (running from the project root)
 *   <exe>/assets/sprites
 *   <exe>/../assets/sprites
 *   <exe>/../share/starfall/sprites   (installed layout)
 */

namespace Starfall {

    public class SpriteRegion : Object {
        public int x;
        public int y;
        public int w;
        public int h;
        public int frames;
    }

    public class Assets : Object {
        static Assets? _instance;

        public static Assets instance () {
            if (_instance == null)
                _instance = new Assets ();
            return _instance;
        }

        public bool loaded { get; private set; default = false; }

        Raylib.Texture2D atlas;
        HashTable<string, SpriteRegion> regions;

        Assets () {
            regions = new HashTable<string, SpriteRegion> (str_hash, str_equal);

            string? dir = find_dir ();
            if (dir == null) {
                message ("sprites: no atlas found, using primitive shapes");
                return;
            }

            string png = Path.build_filename (dir, "atlas.png");
            string txt = Path.build_filename (dir, "atlas.txt");

            atlas = Raylib.load_texture (png);
            if (!Raylib.is_texture_valid (atlas)) {
                warning ("sprites: failed to load %s", png);
                return;
            }
            Raylib.set_texture_filter (atlas, Raylib.TextureFilter.POINT);

            if (!parse_manifest (txt)) {
                warning ("sprites: failed to read %s", txt);
                return;
            }

            loaded = true;
            message ("sprites: loaded %u regions from %s", regions.size (), dir);
        }

        static string? find_dir () {
            string[] candidates = {};

            string? env = Environment.get_variable ("STARFALL_ASSETS");
            if (env != null)
                candidates += env;

            candidates += Path.build_filename ("assets", "sprites");

            unowned string exe = Raylib.get_application_directory ();
            candidates += Path.build_filename (exe, "assets", "sprites");
            candidates += Path.build_filename (exe, "..", "assets", "sprites");
            candidates += Path.build_filename (exe, "..", "share", "starfall", "sprites");

            foreach (unowned string c in candidates) {
                if (FileUtils.test (Path.build_filename (c, "atlas.png"), FileTest.EXISTS)
                    && FileUtils.test (Path.build_filename (c, "atlas.txt"), FileTest.EXISTS))
                    return c;
            }
            return null;
        }

        bool parse_manifest (string path) {
            string body;
            try {
                FileUtils.get_contents (path, out body);
            } catch (FileError e) {
                return false;
            }

            foreach (unowned string raw in body.split ("\n")) {
                string line = raw.strip ();
                if (line == "" || line.has_prefix ("#"))
                    continue;

                string[] f = Regex.split_simple ("\\s+", line);
                if (f.length < 5)
                    continue;

                var r = new SpriteRegion ();
                r.x      = int.parse (f[1]);
                r.y      = int.parse (f[2]);
                r.w      = int.parse (f[3]);
                r.h      = int.parse (f[4]);
                r.frames = (f.length >= 6) ? int.max (1, int.parse (f[5])) : 1;
                regions.insert (f[0], r);
            }
            return regions.size () > 0;
        }

        /*
         * Draw `name` centred on `center`, scaled so its height is `dest_h`
         * (width follows the sprite's aspect), rotated `rotation` degrees.
         * Returns false if the atlas isn't loaded or the region is unknown, so
         * the caller can fall back to primitives.
         */
        public bool draw_sprite (string name, Raylib.Vector2 center, float dest_h,
                                 float rotation, Raylib.Color tint, int frame = 0) {
            if (!loaded)
                return false;

            SpriteRegion? r = regions.lookup (name);
            if (r == null)
                return false;

            float fw = (r.frames > 1) ? (float) r.w / r.frames : (float) r.w;
            float fx = r.x + ((r.frames > 1) ? (frame % r.frames) * fw : 0.0f);
            float dest_w = dest_h * (fw / r.h);

            Raylib.Rectangle src = { fx, (float) r.y, fw, (float) r.h };
            Raylib.Rectangle dst = { center.x, center.y, dest_w, dest_h };
            Raylib.draw_texture_pro (atlas, src, dst, { dest_w / 2.0f, dest_h / 2.0f },
                                     rotation, tint);
            return true;
        }

        public int frame_count (string name) {
            SpriteRegion? r = regions.lookup (name);
            return (r != null) ? r.frames : 1;
        }
    }
}
