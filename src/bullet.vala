/*
 * Bullets for both sides, served from a fixed-size pool so nothing allocates
 * mid-game. A shot that can't find a free slot is simply dropped.
 */

namespace Starfall {

    public class Bullet : Entity {
        public bool from_player;
        public Raylib.Color color;

        // Homing missiles: while steer_time lasts, the heading turns toward a
        // target at `turn` rad/s, keeping the speed at `speed`. Enemy / boss
        // missiles chase the player; player missiles chase the nearest enemy.
        public bool  missile;
        public float speed;
        public float turn;
        public float steer_time;

        // Player power-up shots.
        public float damage = 1.0f;   // hp removed per hit
        public int   pierce;          // extra enemies the shot passes through (railgun)
        public float aoe;             // > 0: splash radius on impact (spread battery)

        public override void update (float dt) {
            pos.x += vel.x * dt;
            pos.y += vel.y * dt;
        }

        public void steer (Raylib.Vector2 target, float dt) {
            if (turn <= 0.0f || steer_time <= 0.0f) return;
            steer_time -= dt;

            float cur = Math.atan2f (vel.y, vel.x);
            float des = Math.atan2f (target.y - pos.y, target.x - pos.x);
            float diff = des - cur;
            while (diff >  3.1415927f) diff -= 6.2831853f;
            while (diff < -3.1415927f) diff += 6.2831853f;

            float lim = turn * dt;
            if (diff >  lim) diff =  lim;
            if (diff < -lim) diff = -lim;

            float na = cur + diff;
            float sp = (speed > 0.0f) ? speed
                     : Math.sqrtf (vel.x * vel.x + vel.y * vel.y);
            vel.x = Math.cosf (na) * sp;
            vel.y = Math.sinf (na) * sp;
        }

        public override void draw () {
            if (missile) {
                float ang = Math.atan2f (vel.y, vel.x) * (180.0f / 3.1415927f) + 90.0f;
                if (Assets.instance ().draw_sprite ("missile", pos, radius * 5.0f, ang, color))
                    return;
                Raylib.draw_circle_v (pos, radius, color);
                Raylib.draw_circle_v (pos, radius * 0.45f, Palette.YELLOW);
                return;
            }

            if (pierce > 0) {   // railgun slug: a bright vertical streak
                Raylib.draw_rectangle_v ({ pos.x - 2.5f, pos.y - 15.0f }, { 5.0f, 30.0f },
                                         Raylib.fade (Palette.SKYBLUE, 0.7f));
                Raylib.draw_rectangle_v ({ pos.x - 1.0f, pos.y - 17.0f }, { 2.0f, 34.0f },
                                         Palette.RAYWHITE);
                return;
            }

            if (aoe > 0.0f) {   // spread-battery pellet
                Raylib.draw_circle_v (pos, radius, Palette.ORANGE);
                Raylib.draw_circle_v (pos, radius * 0.5f, Palette.YELLOW);
                return;
            }

            string sprite = from_player ? "bullet_player" : "bullet_enemy";
            float dest_h = radius * (from_player ? 4.5f : 3.2f);
            if (Assets.instance ().draw_sprite (sprite, pos, dest_h, 0.0f, Palette.WHITE))
                return;

            Raylib.draw_rectangle_v ({ pos.x - radius, pos.y - radius * 2.0f },
                                     { radius * 2.0f, radius * 4.0f }, color);
        }
    }

    public class BulletPool : Object {
        public const int CAP = 512;
        public Bullet[] items;

        public BulletPool () {
            items = new Bullet[CAP];
            for (int i = 0; i < CAP; i++)
                items[i] = new Bullet ();
        }

        public void clear () {
            foreach (var b in items)
                b.active = false;
        }

        /* Wipe every hostile shot - used by the screen-clearing bomb. */
        public void clear_enemy () {
            foreach (var b in items)
                if (b.active && !b.from_player) b.active = false;
        }

        public Bullet? spawn (Raylib.Vector2 pos, Raylib.Vector2 vel,
                              bool from_player, float radius, Raylib.Color color) {
            foreach (var b in items) {
                if (b.active) continue;
                b.pos         = pos;
                b.vel         = vel;
                b.from_player = from_player;
                b.radius      = radius;
                b.color       = color;
                b.missile     = false;
                b.speed       = 0.0f;
                b.turn        = 0.0f;
                b.steer_time  = 0.0f;
                b.damage      = 1.0f;
                b.pierce      = 0;
                b.aoe         = 0.0f;
                b.active      = true;
                return b;
            }
            return null;
        }

        public void update (float dt, Player player, EnemyPool enemies, Boss boss) {
            foreach (var b in items) {
                if (!b.active) continue;

                if (b.missile) {
                    if (b.from_player) {
                        Raylib.Vector2 t;
                        if (nearest_target (b.pos, enemies, boss, out t))
                            b.steer (t, dt);
                    } else {
                        b.steer (player.pos, dt);   // boss / enemy guided missiles
                    }
                }

                b.update (dt);
                if (b.off_screen ()) b.active = false;
            }
        }

        /* Closest live enemy (or the boss) to `from`, for player seekers. */
        static bool nearest_target (Raylib.Vector2 from, EnemyPool enemies, Boss boss,
                                    out Raylib.Vector2 target) {
            float best = float.MAX;
            target = from;
            bool found = false;

            foreach (var e in enemies.items) {
                if (!e.active) continue;
                float dx = e.pos.x - from.x;
                float dy = e.pos.y - from.y;
                float d = dx * dx + dy * dy;
                if (d < best) { best = d; target = e.pos; found = true; }
            }
            if (boss.hittable ()) {
                float dx = boss.pos.x - from.x;
                float dy = boss.pos.y - from.y;
                if (dx * dx + dy * dy < best) { target = boss.pos; found = true; }
            }
            return found;
        }

        public void draw () {
            foreach (var b in items) {
                if (b.active) b.draw ();
            }
        }
    }
}
