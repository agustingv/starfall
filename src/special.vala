/*
 * The special weapon: a swarm of homing missiles, plus the recharge pickups
 * that enemies drop. PlayScreen owns one MissilePool + one PickupPool and wires
 * the collisions / scoring, the same way it does for bullets.
 */

namespace Starfall {

    public class Missile : Object {
        public Raylib.Vector2 pos;
        public Raylib.Vector2 vel;
        public float radius;
        public bool  active;

        float          life;
        unowned Enemy? target;

        public void launch (Raylib.Vector2 from, float angle, Enemy? target) {
            this.pos    = from;
            float speed = 130.0f;
            this.vel    = { Math.sinf (angle) * speed, -Math.cosf (angle) * speed };
            this.radius = 4.0f;
            this.life   = 2.6f;
            this.target = target;
            this.active = true;
        }

        public void update (float dt) {
            life -= dt;
            if (life <= 0.0f) {
                active = false;
                target = null;
                return;
            }

            if (target != null && target.active) {
                Raylib.Vector2 d = { target.pos.x - pos.x, target.pos.y - pos.y };
                float len = Math.sqrtf (d.x * d.x + d.y * d.y);
                if (len > 0.001f) {
                    float sp = 320.0f;
                    float k  = clampf (7.0f * dt, 0.0f, 1.0f);
                    vel.x += (d.x / len * sp - vel.x) * k;
                    vel.y += (d.y / len * sp - vel.y) * k;
                }
            } else {
                // No live target: keep accelerating along the current heading.
                vel.x *= 1.0f + 0.7f * dt;
                vel.y *= 1.0f + 0.7f * dt;
            }

            pos.x += vel.x * dt;
            pos.y += vel.y * dt;

            if (pos.y < -Config.MARGIN
                || pos.x < -Config.MARGIN || pos.x > Config.SCREEN_W + Config.MARGIN) {
                active = false;
                target = null;
            }
        }

        public void draw () {
            float ang = Math.atan2f (vel.y, vel.x) * (180.0f / 3.1415927f) + 90.0f;
            if (Assets.instance ().draw_sprite ("missile", pos, radius * 4.5f, ang, Palette.WHITE))
                return;
            Raylib.draw_circle_v (pos, radius, Palette.SKYBLUE);
        }
    }

    public class MissilePool : Object {
        public const int CAP = 28;
        public Missile[] items;

        public MissilePool () {
            items = new Missile[CAP];
            for (int i = 0; i < CAP; i++)
                items[i] = new Missile ();
        }

        public void clear () {
            foreach (var m in items)
                m.active = false;
        }

        public Missile? launch (Raylib.Vector2 from, float angle, Enemy? target) {
            foreach (var m in items) {
                if (m.active) continue;
                m.launch (from, angle, target);
                return m;
            }
            return null;
        }

        public void update (float dt) {
            foreach (var m in items)
                if (m.active) m.update (dt);
        }

        public void draw () {
            foreach (var m in items)
                if (m.active) m.draw ();
        }
    }

    public class Pickup : Object {
        public Raylib.Vector2 pos;
        public float radius;
        public bool  active;
        float wob;

        public void spawn (Raylib.Vector2 at) {
            pos    = at;
            radius = 10.0f;
            wob    = Raylib.get_random_value (0, 628) / 100.0f;
            active = true;
        }

        public void update (float dt) {
            wob   += dt * 3.0f;
            pos.y += 55.0f * dt;
            pos.x += Math.sinf (wob) * 18.0f * dt;
            if (pos.y > Config.SCREEN_H + Config.MARGIN)
                active = false;
        }

        public void draw () {
            float pulse = 0.85f + 0.15f * Math.sinf ((float) Raylib.get_time () * 8.0f);
            if (Assets.instance ().draw_sprite ("pickup", pos, radius * 2.4f * pulse,
                                                0.0f, Palette.WHITE))
                return;
            Raylib.draw_circle_v (pos, radius * pulse, Palette.SKYBLUE);
            Raylib.draw_circle_v (pos, radius * 0.4f, Palette.WHITE);
        }
    }

    public class PickupPool : Object {
        public const int CAP = 16;
        public Pickup[] items;

        public PickupPool () {
            items = new Pickup[CAP];
            for (int i = 0; i < CAP; i++)
                items[i] = new Pickup ();
        }

        public void clear () {
            foreach (var p in items)
                p.active = false;
        }

        public void spawn (Raylib.Vector2 at) {
            foreach (var p in items) {
                if (p.active) continue;
                p.spawn (at);
                return;
            }
        }

        public void update (float dt) {
            foreach (var p in items)
                if (p.active) p.update (dt);
        }

        public void draw () {
            foreach (var p in items)
                if (p.active) p.draw ();
        }
    }
}
