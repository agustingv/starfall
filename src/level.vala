/*
 * Campaign data and the per-section spawn script.
 *
 * A level is 3 sections plus a boss. A section is a timed list of spawn events;
 * it's considered clear once every event has fired and no enemies remain. Only
 * level 1 is hand-tuned in spirit here - the rest scale procedurally off the
 * level / section index. Replace SectionScript's body with an authored timeline
 * when you want real level design.
 */

namespace Starfall {

    public enum Formation {
        ROW_5,
        ROW_3,
        V_5,
        COLUMNS,
        DIAMOND,
    }

    public struct SpawnEvent {
        public float     at;         // seconds from the start of the section
        public Formation formation;
        public EnemyKind kind;
    }

    /* Static campaign flavour text. */
    namespace Levels {

        public string title (int level) {
            switch (level) {
                case 1:  return "TITAN ASCENT";
                case 2:  return "THE ASTEROID LINE";
                case 3:  return "MARS APPROACH";
                case 4:  return "LUNAR SHADOW";
                default: return "EARTH";
            }
        }

        public string tagline (int level) {
            switch (level) {
                case 1:  return "Break the blockade above the launch fields.";
                case 2:  return "Their mining fleet turned the belt into a wall.";
                case 3:  return "Retake the red planet's orbital yards.";
                case 4:  return "The siege guns of the Moon must fall.";
                default: return "Liberate the homeworld. End it.";
            }
        }

        public string boss_name (int level) {
            switch (level) {
                case 1:  return "BLOCKADE WARDEN";
                case 2:  return "BELT CRUSHER";
                case 3:  return "YARD SOVEREIGN";
                case 4:  return "SIEGE COLOSSUS";
                default: return "ANDROMEDAN THRONE";
            }
        }
    }

    public class SectionScript : Object {
        public SpawnEvent[] events;
        public float last_at;        // time of the final spawn event

        // Formations are handed out in this fixed rotation (offset by section);
        // only the enemy *kind* per wave is random. Kept here so enemy_count ()
        // can reconstruct a stage's roster exactly.
        const Formation[] CYCLE = {
            Formation.ROW_5, Formation.V_5, Formation.ROW_3,
            Formation.COLUMNS, Formation.DIAMOND,
        };

        // Waves per stage. Grows with level + section but caps out, so late
        // stages stay intense without becoming unwinnable walls of ships.
        const int MAX_BURSTS = 8;

        static int burst_count (int level, int section) {
            return int.min (3 + level + section, MAX_BURSTS);
        }

        /* How many alien craft a stage releases in total (deterministic). */
        public static int enemy_count (int level, int section) {
            int total = 0;
            int bursts = burst_count (level, section);
            for (int i = 0; i < bursts; i++)
                total += Formations.size (CYCLE[(i + section) % CYCLE.length]);
            return total;
        }

        public SectionScript (int level, int section) {
            int bursts = burst_count (level, section);
            float gap  = clampf (3.0f - 0.11f * level - 0.09f * section, 1.4f, 3.0f);

            events = new SpawnEvent[bursts];
            float t = 1.0f;
            for (int i = 0; i < bursts; i++) {
                Formation f;
                EnemyKind k;
                pick (level, section, i, out f, out k);
                events[i].at        = t;
                events[i].formation = f;
                events[i].kind      = k;
                t += gap;
            }
            last_at = (bursts > 0) ? events[bursts - 1].at : 0.0f;
        }

        /* Each level fields its own mix of craft; later slots in a level's list
         * are its heavier / nastier types, favoured as the level goes on. */
        static EnemyKind[] roster (int level) {
            switch (level) {
                case 1:
                    return { EnemyKind.GRUNT, EnemyKind.GRUNT, EnemyKind.DARTER };
                case 2:
                    return { EnemyKind.DARTER, EnemyKind.WEAVER,
                             EnemyKind.WEAVER, EnemyKind.SENTINEL };
                case 3:
                    return { EnemyKind.WEAVER, EnemyKind.SENTINEL,
                             EnemyKind.BRUTE, EnemyKind.HUNTER };
                case 4:
                    return { EnemyKind.SENTINEL, EnemyKind.BRUTE,
                             EnemyKind.HUNTER, EnemyKind.RACER, EnemyKind.RACER };
                default:
                    return { EnemyKind.HUNTER, EnemyKind.RACER,
                             EnemyKind.BRUTE, EnemyKind.WARDEN, EnemyKind.WARDEN };
            }
        }

        static void pick (int level, int section, int i, out Formation f, out EnemyKind k) {
            f = CYCLE[(i + section) % CYCLE.length];

            EnemyKind[] r = roster (level);
            int idx = (i * 2 + section + Raylib.get_random_value (0, 2)) % r.length;
            k = r[idx];
        }
    }

    /* Turns a Formation into actual enemies in the pool. */
    namespace Formations {

        /* Craft per formation - must match the spawn helpers below. */
        public int size (Formation f) {
            switch (f) {
                case Formation.ROW_5:   return 5;
                case Formation.ROW_3:   return 3;
                case Formation.V_5:     return 5;
                case Formation.COLUMNS: return 6;
                default:                return 4;   // DIAMOND
            }
        }

        public void spawn (EnemyPool pool, Formation f, EnemyKind kind) {
            switch (f) {
                case Formation.ROW_5:   row (pool, 5, kind);     break;
                case Formation.ROW_3:   row (pool, 3, kind);     break;
                case Formation.V_5:     vee (pool, 5, kind);     break;
                case Formation.COLUMNS: columns (pool, kind);    break;
                default:                diamond (pool, kind);    break;
            }
        }

        void row (EnemyPool pool, int count, EnemyKind kind) {
            float gap = Config.SCREEN_W / (count + 1.0f);
            for (int i = 0; i < count; i++)
                pool.spawn (gap * (i + 1), -40.0f, kind);
        }

        void vee (EnemyPool pool, int count, EnemyKind kind) {
            float cx = Config.SCREEN_W / 2.0f;
            for (int i = 0; i < count; i++) {
                float off = (i - count / 2) * 46.0f;
                pool.spawn (cx + off, -40.0f - absf (off), kind);
            }
        }

        void columns (EnemyPool pool, EnemyKind kind) {
            for (int i = 0; i < 3; i++) {
                pool.spawn (Config.SCREEN_W * 0.28f, -40.0f - i * 60.0f, kind);
                pool.spawn (Config.SCREEN_W * 0.72f, -40.0f - i * 60.0f, kind);
            }
        }

        void diamond (EnemyPool pool, EnemyKind kind) {
            float cx = Config.SCREEN_W / 2.0f;
            pool.spawn (cx,          -40.0f,  kind);
            pool.spawn (cx - 44.0f,  -80.0f,  kind);
            pool.spawn (cx + 44.0f,  -80.0f,  kind);
            pool.spawn (cx,          -120.0f, kind);
        }
    }
}
