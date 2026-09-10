/*
 * Core types shared across the game: tunables, the input snapshot, the Entity
 * base class, and a small colour palette.
 */

namespace Starfall {

    namespace Config {
        // Logical render resolution. All game logic and drawing happen at this
        // size; Game scales it to fit the actual window (see Game.present()).
        public const int   SCREEN_W = 480;
        public const int   SCREEN_H = 720;
        public const float TICK     = 1.0f / 60.0f;   // fixed simulation step
        public const float MARGIN   = 80.0f;          // off-screen cull distance

        // Campaign shape: 5 levels, 3 sections each, a boss to close every level.
        public const int LEVELS             = 5;
        public const int SECTIONS_PER_LEVEL = 3;

        // Percent chance a destroyed enemy drops a power-up (weapon / shield /
        // bomb recharge). The kind is then rolled in Pickups.random_kind ().
        public const int POWERUP_DROP_PCT = 12;
    }

    /* A per-frame snapshot of what the player is asking for, already merged
     * from keyboard + gamepad and clamped to [-1, 1]. */
    public struct Input {
        public float move_x;
        public float move_y;
        public bool  firing;
    }

    public float clampf (float v, float lo, float hi) {
        return v < lo ? lo : (v > hi ? hi : v);
    }

    public float absf (float v) {
        return v < 0.0f ? -v : v;
    }

    public float minf (float a, float b) {
        return a < b ? a : b;
    }

    /* Anything that moves, can leave the play area, and draws itself. */
    public abstract class Entity : Object {
        public Raylib.Vector2 pos;
        public Raylib.Vector2 vel;
        public float radius;
        public bool  active;

        public bool off_screen () {
            return pos.y < -Config.MARGIN || pos.y > Config.SCREEN_H + Config.MARGIN
                || pos.x < -Config.MARGIN || pos.x > Config.SCREEN_W + Config.MARGIN;
        }

        public abstract void update (float dt);
        public abstract void draw ();
    }

    /* raylib's colour names are C macros, not bound in the vapi; define the
     * handful we use here as plain constants. */
    namespace Palette {
        public const Raylib.Color BG        = {   8,  10,  24, 255 };
        public const Raylib.Color BLACK     = {   0,   0,   0, 255 };
        public const Raylib.Color WHITE     = { 255, 255, 255, 255 };
        public const Raylib.Color RAYWHITE  = { 245, 245, 245, 255 };
        public const Raylib.Color LIGHTGRAY = { 200, 200, 200, 255 };
        public const Raylib.Color GRAY      = { 130, 130, 130, 255 };
        public const Raylib.Color YELLOW    = { 253, 249,   0, 255 };
        public const Raylib.Color ORANGE    = { 255, 161,   0, 255 };
        public const Raylib.Color RED       = { 230,  41,  55, 255 };
        public const Raylib.Color LIME      = {   0, 158,  47, 255 };
        public const Raylib.Color SKYBLUE   = { 102, 191, 255, 255 };
        public const Raylib.Color MAGENTA   = { 255,   0, 255, 255 };
    }
}
