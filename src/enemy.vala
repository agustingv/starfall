/*
 * Alien craft. Eight kinds, drawn from a per-level roster (see level.vala), each
 * with its own movement and weapon so every stage fights differently:
 *
 *   GRUNT    slow wide sway            single aimed bolt
 *   DARTER   fast tight sway           quick two-bolt burst
 *   WEAVER   broad fast weave          angled bolt pair
 *   SENTINEL drops to a hold band      charged laser beam (see beam.vala)
 *   BRUTE    slow big sway, tanky      three-way bolt spread
 *   HUNTER   slides toward the player  guided missile (the player can shoot it)
 *   RACER    steep diagonal dive       fast bolt volley along its heading
 *   WARDEN   slow menacing weave       alternates missile fan / wide spread
 *
 * Pooled, like bullets.
 */

namespace Starfall {

    public enum EnemyKind {
        GRUNT    = 0,
        DARTER   = 1,
        WEAVER   = 2,
        SENTINEL = 3,
        BRUTE    = 4,
        HUNTER   = 5,
        RACER    = 6,
        WARDEN   = 7,
    }

    enum EnemyWeapon {
        BOLT,           // 1 aimed
        BURST,          // 2 aimed, tight
        PAIR,           // 2 aimed, angled apart
        SPREAD,         // 3 aimed, fanned
        DIVE_BOLTS,     // 3 fast, along the ship's heading
        MISSILE,        // 1 guided
        BEAM,           // charged laser (see beam.vala)
        MISSILE_SPREAD, // alternate: 2 guided, then a 5-bolt fan
    }

    public class Enemy : Entity {
        public float hp;
        public float hp_max;
        public int   score_value;
        public EnemyKind kind;

        EnemyWeapon weapon;
        float base_x;
        float base_vy;        // descent speed to resume with after a hold
        float sway_phase;
        float sway_freq;
        float sway_amp;
        float chase_k;        // > 0: base_x eases toward the player's x
        float hold_y;         // > 0: stop descending here for a while
        bool  free_x;         // integrate vel.x instead of the sway curve
        bool  holding;
        float hold_timer;
        int   alt;            // toggles MISSILE_SPREAD between its two volleys
        float fire_interval;
        float fire_timer;

        public void configure (float x, float y, EnemyKind kind) {
            this.kind       = kind;
            this.base_x     = x;
            this.pos        = { x, y };
            this.vel        = { 0.0f, 0.0f };
            this.active     = true;
            this.sway_phase = Raylib.get_random_value (0, 628) / 100.0f;
            this.chase_k    = 0.0f;
            this.hold_y     = 0.0f;
            this.free_x     = false;
            this.holding    = false;
            this.hold_timer = 0.0f;
            this.alt        = 0;

            switch (kind) {
                case EnemyKind.GRUNT:
                    radius = 14.0f; hp = 1.0f; score_value = 100;
                    vel.y = 70.0f;  sway_amp = 28.0f; sway_freq = 1.4f;
                    weapon = EnemyWeapon.BOLT;   fire_interval = 2.4f;
                    break;
                case EnemyKind.DARTER:
                    radius = 11.0f; hp = 1.0f; score_value = 150;
                    vel.y = 135.0f; sway_amp = 10.0f; sway_freq = 3.0f;
                    weapon = EnemyWeapon.BURST;  fire_interval = 2.8f;
                    break;
                case EnemyKind.WEAVER:
                    radius = 15.0f; hp = 2.0f; score_value = 200;
                    vel.y = 40.0f;  sway_amp = 120.0f; sway_freq = 1.7f;
                    weapon = EnemyWeapon.PAIR;   fire_interval = 2.2f;
                    break;
                case EnemyKind.SENTINEL:
                    radius = 16.0f; hp = 3.0f; score_value = 300;
                    vel.y = 95.0f;  sway_amp = 6.0f; sway_freq = 1.0f;
                    hold_y = 96.0f + Raylib.get_random_value (0, 80);
                    base_vy = 70.0f;
                    weapon = EnemyWeapon.BEAM;   fire_interval = 2.6f;
                    break;
                case EnemyKind.BRUTE:
                    radius = 20.0f; hp = 4.0f; score_value = 400;
                    vel.y = 45.0f;  sway_amp = 42.0f; sway_freq = 0.8f;
                    weapon = EnemyWeapon.SPREAD; fire_interval = 2.0f;
                    break;
                case EnemyKind.HUNTER:
                    radius = 14.0f; hp = 2.0f; score_value = 300;
                    vel.y = 52.0f;  sway_amp = 8.0f; sway_freq = 1.6f;
                    chase_k = 70.0f;
                    weapon = EnemyWeapon.MISSILE; fire_interval = 3.1f;
                    break;
                case EnemyKind.RACER:
                    radius = 11.0f; hp = 1.0f; score_value = 220;
                    vel.y = 205.0f; sway_amp = 0.0f; sway_freq = 0.0f;
                    free_x = true;
                    vel.x = (x < Config.SCREEN_W / 2.0f) ? 150.0f : -150.0f;
                    weapon = EnemyWeapon.DIVE_BOLTS; fire_interval = 1.1f;
                    break;
                default: // WARDEN
                    radius = 22.0f; hp = 6.0f; score_value = 700;
                    vel.y = 44.0f;  sway_amp = 64.0f; sway_freq = 0.7f;
                    chase_k = 24.0f;
                    weapon = EnemyWeapon.MISSILE_SPREAD; fire_interval = 2.4f;
                    break;
            }

            hp_max     = hp;
            fire_timer = fire_interval * 0.5f;
        }

        /* Horizontal tracking - kinds with chase_k drift toward the player. */
        public void steer (float dt, Player player) {
            if (chase_k <= 0.0f) return;
            float target = clampf (player.pos.x, 40.0f, Config.SCREEN_W - 40.0f);
            float d    = target - base_x;
            float step = chase_k * dt;
            base_x += (d > step) ? step : (d < -step ? -step : d);
        }

        public override void update (float dt) {
            sway_phase += sway_freq * dt;

            if (holding) {
                hold_timer -= dt;
                if (hold_timer <= 0.0f) {
                    holding = false;
                    hold_y  = 0.0f;      // don't re-trigger the hold
                    vel.y   = base_vy;
                }
            } else {
                pos.y += vel.y * dt;
                if (hold_y > 0.0f && pos.y >= hold_y) {
                    pos.y      = hold_y;
                    holding    = true;
                    hold_timer = 4.5f;
                }
            }

            if (free_x)
                pos.x += vel.x * dt;
            else
                pos.x = base_x + Math.sinf (sway_phase) * sway_amp;

            if (pos.y > Config.SCREEN_H + Config.MARGIN
                || pos.x < -Config.MARGIN - 60.0f
                || pos.x > Config.SCREEN_W + Config.MARGIN + 60.0f)
                active = false;
        }

        public void try_fire (float dt, BulletPool bullets, EnemyBeamPool beams, Player player) {
            fire_timer -= dt;
            if (fire_timer > 0.0f) return;
            fire_timer = fire_interval;

            switch (weapon) {
                case EnemyWeapon.BOLT:
                    fire_bolts (bullets, player, 1, 0.0f, 190.0f);
                    break;
                case EnemyWeapon.BURST:
                    fire_bolts (bullets, player, 2, 0.09f, 235.0f);
                    break;
                case EnemyWeapon.PAIR:
                    fire_bolts (bullets, player, 2, 0.18f, 205.0f);
                    break;
                case EnemyWeapon.SPREAD:
                    fire_bolts (bullets, player, 3, 0.24f, 155.0f);
                    break;
                case EnemyWeapon.DIVE_BOLTS:
                    fire_dive (bullets);
                    break;
                case EnemyWeapon.MISSILE:
                    fire_missiles (bullets, player, 1);
                    break;
                case EnemyWeapon.BEAM:
                    beams.spawn (this, player);
                    Audio.instance ().play ("special", 0.10f, 0.75f);
                    break;
                case EnemyWeapon.MISSILE_SPREAD:
                    if ((alt++ & 1) == 0) fire_missiles (bullets, player, 2);
                    else                  fire_bolts (bullets, player, 5, 0.32f, 160.0f);
                    break;
            }
        }

        void aim (Player player, out float bx, out float by) {
            float dx = player.pos.x - pos.x;
            float dy = player.pos.y - pos.y;
            float len = Math.sqrtf (dx * dx + dy * dy);
            if (len < 0.001f) len = 1.0f;
            bx = dx / len;
            by = dy / len;
        }

        void fire_bolts (BulletPool bullets, Player player, int count, float spread, float speed) {
            float bx, by;
            aim (player, out bx, out by);
            float base_ang = Math.atan2f (by, bx);

            for (int i = 0; i < count; i++) {
                float off = (count == 1) ? 0.0f
                          : (-spread + 2.0f * spread * i / (count - 1));
                float a = base_ang + off;
                bullets.spawn ({ pos.x, pos.y + radius },
                               { Math.cosf (a) * speed, Math.sinf (a) * speed },
                               false, 4.0f, Palette.RED);
            }
            Audio.instance ().play ("shot_enemy", 0.10f, 0.5f);
        }

        void fire_dive (BulletPool bullets) {
            float vx = vel.x * 0.35f;
            for (int i = -1; i <= 1; i++)
                bullets.spawn ({ pos.x + i * 6.0f, pos.y + radius },
                               { vx, 300.0f }, false, 3.5f, Palette.ORANGE);
            Audio.instance ().play ("shot_enemy", 0.10f, 0.8f);
        }

        void fire_missiles (BulletPool bullets, Player player, int n) {
            float bx, by;
            aim (player, out bx, out by);
            float base_ang = Math.atan2f (by, bx);

            for (int i = 0; i < n; i++) {
                float off = (n == 1) ? 0.0f : (-0.30f + 0.60f * i / (n - 1));
                float a = base_ang + off;
                var m = bullets.spawn ({ pos.x, pos.y + radius },
                                       { Math.cosf (a) * 120.0f, Math.sinf (a) * 120.0f },
                                       false, 6.0f, Palette.ORANGE);
                if (m != null) {
                    m.missile    = true;
                    m.speed      = 150.0f;
                    m.turn       = 2.1f;
                    m.steer_time = 2.6f;
                }
            }
            Audio.instance ().play ("shot_enemy", 0.10f, 0.35f);
        }

        public override void draw () {
            string sprite;
            Raylib.Color body;
            float scale;
            switch (kind) {
                case EnemyKind.GRUNT:
                    sprite = "enemy_grunt";    body = Palette.SKYBLUE;   scale = 2.7f; break;
                case EnemyKind.DARTER:
                    sprite = "enemy_darter";   body = Palette.LIME;      scale = 2.7f; break;
                case EnemyKind.WEAVER:
                    sprite = "enemy_weaver";   body = Palette.ORANGE;    scale = 2.6f; break;
                case EnemyKind.SENTINEL:
                    sprite = "enemy_sentinel"; body = Palette.SKYBLUE;   scale = 2.4f; break;
                case EnemyKind.BRUTE:
                    sprite = "enemy_brute";    body = Palette.MAGENTA;   scale = 2.4f; break;
                case EnemyKind.HUNTER:
                    sprite = "enemy_hunter";   body = Palette.MAGENTA;   scale = 2.6f; break;
                case EnemyKind.RACER:
                    sprite = "enemy_racer";    body = Palette.LIME;      scale = 2.8f; break;
                default: // WARDEN
                    sprite = "enemy_warden";   body = Palette.RED;       scale = 2.3f; break;
            }

            if (!Assets.instance ().draw_sprite (sprite, pos, radius * scale, 0.0f, Palette.WHITE)) {
                Raylib.draw_circle_v (pos, radius, body);
                Raylib.draw_circle_v (pos, radius * 0.45f, Raylib.fade (Palette.BLACK, 0.4f));
            }

            // Charging telegraph: a bright ring while the beam winds up.
            if (kind == EnemyKind.SENTINEL && holding)
                Raylib.draw_circle_v (pos, radius + 4.0f,
                                      Raylib.fade (Palette.YELLOW, 0.18f));

            if (hp_max > 1.0f && hp < hp_max) {
                float w = radius * 2.0f * (hp / hp_max);
                Raylib.draw_rectangle_v ({ pos.x - radius, pos.y - radius - 8.0f },
                                         { w, 3.0f }, Palette.YELLOW);
            }
        }
    }

    public class EnemyPool : Object {
        public const int CAP = 64;
        public Enemy[] items;

        public EnemyPool () {
            items = new Enemy[CAP];
            for (int i = 0; i < CAP; i++)
                items[i] = new Enemy ();
        }

        public void clear () {
            foreach (var e in items)
                e.active = false;
        }

        public int active_count () {
            int n = 0;
            foreach (var e in items)
                if (e.active) n++;
            return n;
        }

        public Enemy? spawn (float x, float y, EnemyKind kind) {
            foreach (var e in items) {
                if (e.active) continue;
                e.configure (x, y, kind);
                return e;
            }
            return null;
        }

        public void update (float dt, BulletPool bullets, EnemyBeamPool beams, Player player) {
            foreach (var e in items) {
                if (!e.active) continue;
                e.steer (dt, player);
                e.update (dt);
                if (e.active) e.try_fire (dt, bullets, beams, player);
            }
        }

        public void draw () {
            foreach (var e in items) {
                if (e.active) e.draw ();
            }
        }
    }
}
