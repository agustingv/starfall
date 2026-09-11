/*
 * End-of-level bosses. One class, but every level's boss is its own fight -
 * distinct silhouette (boss_1..boss_5 sprites), movement, weapon set, and
 * toughness:
 *
 *   1 BLOCKADE WARDEN   glides + dwells at the edges   wide slow fans, bullet curtains        easiest
 *   2 BELT CRUSHER      fast lateral charges + bob     rotating spiral, radial rings          moderate
 *   3 YARD SOVEREIGN    mirrors the player's x         aimed rivet streams, homing missiles   hard
 *   4 SIEGE COLOSSUS    near-stationary, ponderous     charged sweeping laser, slow mortars   very hard (tanky)
 *   5 ANDROMEDAN THRONE figure-eight weave, dips       everything, escalating in 3 hp phases  hardest
 *
 * Cadence still eases as a fight goes on (recover ()) so patterns stay readable.
 */

namespace Starfall {

    public class Boss : Object {
        public Raylib.Vector2 pos;
        public float radius;
        public float hp;
        public float max_hp;
        public bool  active;

        int   level;
        float entering;      // > 0 while sliding in from the top
        float move_t;
        float fire_t;
        int   step;          // index into the current boss's pattern rotation
        int   sub;           // sub-shots emitted within a burst / stream
        float spiral_ang;
        float move_speed;
        float anchor_y;
        Raylib.Color tint;

        public void spawn (int level) {
            this.level      = level;
            this.active     = true;
            this.entering   = 1.0f;
            this.move_t     = 0.0f;
            this.fire_t     = 2.2f;
            this.step       = 0;
            this.sub        = 0;
            this.spiral_ang = 0.0f;
            this.tint       = tint_for (level);
            configure ();
            this.hp  = max_hp;
            this.pos = { Config.SCREEN_W / 2.0f, -radius };
        }

        void configure () {
            switch (level) {
                case 1:  radius = 46.0f; max_hp =  75.0f; move_speed = 0.55f; anchor_y =  92.0f; break;
                case 2:  radius = 44.0f; max_hp = 120.0f; move_speed = 1.30f; anchor_y = 104.0f; break;
                case 3:  radius = 40.0f; max_hp = 155.0f; move_speed = 0.90f; anchor_y = 118.0f; break;
                case 4:  radius = 54.0f; max_hp = 230.0f; move_speed = 0.30f; anchor_y =  88.0f; break;
                default: radius = 46.0f; max_hp = 210.0f; move_speed = 1.60f; anchor_y = 104.0f; break;
            }
        }

        public bool hittable () {
            return active && entering <= 0.0f;
        }

        public void damage (float amount) {
            hp -= amount;
            if (hp <= 0.0f) {
                hp = 0.0f;
                active = false;
            }
        }

        int phase () {
            float f = hp / max_hp;
            return (f > 0.66f) ? 0 : ((f > 0.33f) ? 1 : 2);
        }

        /* ---- Update ------------------------------------------------------- */

        public void update (float dt, BulletPool bullets, EnemyBeamPool beams, Player player) {
            if (entering > 0.0f) {
                pos.y += 55.0f * dt;
                if (pos.y >= anchor_y) {
                    pos.y = anchor_y;
                    entering = 0.0f;
                }
                return;
            }

            move_t += dt;
            move (dt, player);

            fire_t -= dt;
            if (fire_t <= 0.0f)
                fire (bullets, beams, player);
        }

        void move (float dt, Player player) {
            float cx   = Config.SCREEN_W / 2.0f;
            float span = cx - radius - 10.0f;

            switch (level) {
                case 1:  // slow glide, dwelling at the edges
                    pos.x = cx + clampf (Math.sinf (move_t * move_speed) * 1.5f, -1.0f, 1.0f) * span;
                    pos.y = anchor_y;
                    break;

                case 2:  // fast lateral charges + a vertical bob
                    pos.x = cx + Math.sinf (move_t * move_speed) * span;
                    pos.y = anchor_y + Math.sinf (move_t * 2.4f) * 20.0f;
                    break;

                case 3:  { // mirror the player's x
                    float tgt = clampf (player.pos.x, cx - span, cx + span);
                    pos.x += (tgt - pos.x) * clampf (1.6f * dt, 0.0f, 1.0f);
                    pos.y  = anchor_y + Math.sinf (move_t * 1.2f) * 10.0f;
                    break;
                }

                case 4:  // near-stationary, heavy
                    pos.x = cx + Math.sinf (move_t * move_speed) * (span * 0.22f);
                    pos.y = anchor_y + Math.sinf (move_t * 0.4f) * 6.0f;
                    break;

                default: // figure-eight weave that dips toward the player
                    pos.x = cx + Math.sinf (move_t * move_speed) * span;
                    pos.y = anchor_y + 24.0f + Math.sinf (move_t * move_speed * 2.0f) * 34.0f;
                    break;
            }
        }

        /* ---- Fire dispatch ---------------------------------------------- */

        void fire (BulletPool b, EnemyBeamPool beams, Player player) {
            switch (level) {
                case 1:  fire_warden (b, player);           break;
                case 2:  fire_crusher (b, player);          break;
                case 3:  fire_sovereign (b, player);        break;
                case 4:  fire_colossus (b, beams, player);  break;
                default: fire_throne (b, beams, player);    break;
            }
        }

        // 1 - BLOCKADE WARDEN: wide slow fans and falling curtains.
        void fire_warden (BulletPool b, Player player) {
            int ph = phase ();
            switch (step % 3) {
                case 0:
                    snd (0.75f);
                    fan (b, player, 3 + ph, 0.24f, 118.0f, Palette.MAGENTA, 5.0f);
                    step++; fire_t = recover (1.6f);
                    break;
                case 1:
                    snd (0.70f);
                    fan (b, player, 3 + ph, 0.55f, 128.0f, Palette.SKYBLUE, 5.0f);
                    step++; fire_t = recover (1.5f);
                    break;
                default:
                    snd (0.90f);
                    curtain (b, 8, (ph >= 2) ? 2 : 1, 96.0f, Palette.MAGENTA);
                    step++; fire_t = recover (1.9f);
                    break;
            }
        }

        // 2 - BELT CRUSHER: rotating spiral, then radial rings.
        void fire_crusher (BulletPool b, Player player) {
            int ph = phase ();
            switch (step % 3) {
                case 0:
                    if (sub == 0) snd (0.95f);
                    spiral (b, 2 + ((ph >= 2) ? 1 : 0), 132.0f, Palette.ORANGE);
                    sub++;
                    if (sub >= 6) { sub = 0; step++; fire_t = recover (1.2f); }
                    else          { fire_t = 0.12f; }
                    break;
                case 1:
                    snd (0.65f);
                    ring (b, 10 + 4 * ph, 118.0f, Palette.RED, spiral_ang);
                    step++; fire_t = recover (1.3f);
                    break;
                default:
                    snd (0.60f);
                    fan (b, player, 3, 0.16f, 195.0f, Palette.ORANGE, 5.0f);
                    step++; fire_t = recover (0.95f);
                    break;
            }
        }

        // 3 - YARD SOVEREIGN: aimed pressure - rivet streams and seekers.
        void fire_sovereign (BulletPool b, Player player) {
            int ph = phase ();
            switch (step % 4) {
                case 0:
                    if (sub == 0) snd (0.55f);
                    fan (b, player, 1, 0.0f, 215.0f, Palette.RED, 4.0f);
                    sub++;
                    if (sub >= 4 + ph) { sub = 0; step++; fire_t = recover (1.1f); }
                    else               { fire_t = 0.09f; }
                    break;
                case 1:
                    snd (0.70f);
                    fan (b, player, 3 + 2 * ph, 0.22f, 175.0f, Palette.RED, 5.0f);
                    step++; fire_t = recover (1.15f);
                    break;
                case 2:
                    snd (0.45f);
                    missiles (b, player, 2 + ((ph >= 2) ? 1 : 0), 150.0f, 2.3f);
                    step++; fire_t = recover (1.5f);
                    break;
                default:
                    snd (0.80f);
                    ring (b, 4, 132.0f, Palette.MAGENTA, spiral_ang);
                    spiral_ang += 0.5f;
                    step++; fire_t = recover (0.8f);
                    break;
            }
        }

        // 4 - SIEGE COLOSSUS: a charged sweeping laser and slow mortars.
        void fire_colossus (BulletPool b, EnemyBeamPool beams, Player player) {
            int ph = phase ();
            switch (step % 3) {
                case 0:
                    beams.spawn_from ({ pos.x, pos.y + radius * 0.4f }, player);
                    Audio.instance ().play ("special", 0.06f, 0.60f);
                    step++; fire_t = recover (2.2f);
                    break;
                case 1:
                    snd (0.45f);
                    fan (b, player, 3 + ph, 0.50f, 92.0f, Palette.LIGHTGRAY, 8.0f);
                    step++; fire_t = recover (1.9f);
                    break;
                default:
                    snd (0.55f);
                    ring (b, 12 + 2 * ph, 84.0f, Palette.LIGHTGRAY, spiral_ang);
                    spiral_ang += 0.3f;
                    step++; fire_t = recover (2.0f);
                    break;
            }
        }

        // 5 - ANDROMEDAN THRONE: the full arsenal, unlocked over 3 hp phases.
        void fire_throne (BulletPool b, EnemyBeamPool beams, Player player) {
            int ph  = phase ();
            int len = 3 + ph * 2;   // 3 patterns at full hp, 5, then 7

            switch (step % len) {
                case 0:
                    if (sub == 0) snd (0.95f);
                    spiral (b, 3, 150.0f, Palette.MAGENTA);
                    sub++;
                    if (sub >= 7) { sub = 0; step++; fire_t = recover (1.0f); }
                    else          { fire_t = 0.10f; }
                    break;
                case 1:
                    snd (0.70f);
                    fan (b, player, 5, 0.26f, 190.0f, Palette.RED, 5.0f);
                    step++; fire_t = recover (0.95f);
                    break;
                case 2:
                    snd (0.60f);
                    ring (b, 16, 150.0f, Palette.ORANGE, spiral_ang);
                    spiral_ang += 0.4f;
                    step++; fire_t = recover (1.0f);
                    break;
                case 3:
                    snd (0.45f);
                    missiles (b, player, 3, 160.0f, 2.6f);
                    step++; fire_t = recover (1.1f);
                    break;
                case 4:
                    snd (0.90f);
                    curtain (b, 10, 2, 150.0f, Palette.MAGENTA);
                    step++; fire_t = recover (1.0f);
                    break;
                case 5:
                    snd (0.80f);
                    ring (b, 14, 140.0f, Palette.RED, spiral_ang);
                    ring (b, 14, 175.0f, Palette.ORANGE, spiral_ang + 0.22f);
                    spiral_ang += 0.5f;
                    step++; fire_t = recover (0.9f);
                    break;
                default:
                    beams.spawn_from ({ pos.x, pos.y + radius * 0.4f }, player);
                    Audio.instance ().play ("special", 0.05f, 0.9f);
                    fan (b, player, 3, 0.12f, 220.0f, Palette.RED, 5.0f);
                    step++; fire_t = recover (1.2f);
                    break;
            }
        }

        /* ---- Shared weapon primitives --------------------------------- */

        void snd (float pitch) {
            Audio.instance ().play ("shot_enemy", 0.05f, pitch);
        }

        void aim (Player player, out float bx, out float by) {
            float dx = player.pos.x - pos.x;
            float dy = player.pos.y - pos.y;
            float len = Math.sqrtf (dx * dx + dy * dy);
            if (len < 0.001f) len = 1.0f;
            bx = dx / len;
            by = dy / len;
        }

        /* `n` shots fanned +-`spread` around the aim at the player. */
        void fan (BulletPool b, Player player, int n, float spread, float speed,
                  Raylib.Color col, float r) {
            float bx, by;
            aim (player, out bx, out by);
            float base_ang = Math.atan2f (by, bx);
            for (int i = 0; i < n; i++) {
                float off = (n == 1) ? 0.0f : (-spread + 2.0f * spread * i / (n - 1));
                float a = base_ang + off;
                b.spawn ({ pos.x, pos.y + radius * 0.5f },
                         { Math.cosf (a) * speed, Math.sinf (a) * speed },
                         false, r, col);
            }
        }

        /* Even ring of `n` shots, first one at `phase0` radians. */
        void ring (BulletPool b, int n, float speed, Raylib.Color col, float phase0) {
            for (int i = 0; i < n; i++) {
                float a = phase0 + i * (6.2831853f / n);
                b.spawn ({ pos.x, pos.y },
                         { Math.cosf (a) * speed, Math.sinf (a) * speed },
                         false, 5.0f, col);
            }
        }

        /* One tick of a rotating spiral - `arms` evenly-spaced streams. */
        void spiral (BulletPool b, int arms, float speed, Raylib.Color col) {
            spiral_ang += 0.36f;
            for (int k = 0; k < arms; k++) {
                float a = spiral_ang + k * (6.2831853f / arms);
                b.spawn ({ pos.x, pos.y },
                         { Math.cosf (a) * speed, Math.sinf (a) * speed },
                         false, 5.0f, col);
            }
        }

        /* Rank of downward shots across the screen with `gaps` columns missing. */
        void curtain (BulletPool b, int cols, int gaps, float speed, Raylib.Color col) {
            float x0 = 40.0f;
            float x1 = Config.SCREEN_W - 40.0f;
            int gap_a = Raylib.get_random_value (0, cols - 1);
            int gap_b = Raylib.get_random_value (0, cols - 1);
            for (int i = 0; i < cols; i++) {
                if (i == gap_a) continue;
                if (gaps > 1 && i == gap_b) continue;
                float x = x0 + (x1 - x0) * i / (cols - 1);
                b.spawn ({ x, pos.y + radius }, { 0.0f, speed }, false, 5.0f, col);
            }
        }

        void missiles (BulletPool b, Player player, int n, float speed, float turn) {
            float bx, by;
            aim (player, out bx, out by);
            float base_ang = Math.atan2f (by, bx);
            for (int i = 0; i < n; i++) {
                float off = (n == 1) ? 0.0f : (-0.30f + 0.60f * i / (n - 1));
                float a = base_ang + off;
                var m = b.spawn ({ pos.x, pos.y + radius * 0.5f },
                                 { Math.cosf (a) * speed * 0.8f, Math.sinf (a) * speed * 0.8f },
                                 false, 6.0f, Palette.ORANGE);
                if (m != null) {
                    m.missile    = true;
                    m.speed      = speed;
                    m.turn       = turn;
                    m.steer_time = 2.0f;
                }
            }
        }

        /* Recovery delay between volleys: near `at_full` at full health,
         * down to ~62% of it as health runs out. */
        float recover (float at_full) {
            float frac = clampf (hp / max_hp, 0.0f, 1.0f);
            return clampf (at_full * (0.62f + 0.38f * frac), 0.42f, at_full);
        }

        /* ---- Draw --------------------------------------------------------- */

        public void draw () {
            // boss_1's sprite is unusually wide, so it needs a smaller
            // height scale than the other bosses to end up a comparable size.
            float sprite_scale = (level == 1) ? 1.5f : 2.6f;
            if (Assets.instance ().draw_sprite (@"boss_$(level)", pos, radius * sprite_scale, 0.0f,
                                           Palette.WHITE))
                return;

            Raylib.draw_circle_v (pos, radius, tint);
            Raylib.draw_circle_v (pos, radius * 0.62f, Raylib.fade (Palette.BLACK, 0.35f));
            Raylib.draw_circle_v (pos, radius * 0.30f, (hp / max_hp > 0.5f) ? tint : Palette.RED);
        }

        public void draw_health_bar () {
            if (!hittable ()) return;
            int x = 20;
            int y = 40;
            int w = Config.SCREEN_W - 40;
            float frac = clampf (hp / max_hp, 0.0f, 1.0f);
            Raylib.draw_rectangle (x, y, w, 10, Raylib.fade (Palette.WHITE, 0.15f));
            Raylib.draw_rectangle (x, y, (int) (w * frac), 10, Palette.RED);
            Raylib.draw_rectangle_lines_ex ({ x, y, w, 10 }, 1.0f, Raylib.fade (Palette.WHITE, 0.4f));
        }

        static Raylib.Color tint_for (int level) {
            switch (level) {
                case 1:  return Palette.SKYBLUE;
                case 2:  return Palette.ORANGE;
                case 3:  return Palette.RED;
                case 4:  return Palette.LIGHTGRAY;
                default: return Palette.MAGENTA;
            }
        }
    }
}
