/*
 * raylib.vapi - minimal hand-written Vala bindings for raylib 5.5
 *
 * This covers only what the scaffold uses plus a little headroom (textures,
 * audio, gamepads). raylib's full API is large; add functions here as you need
 * them - each binding is just the C prototype from raylib.h with an explicit
 * cname. Structs passed/returned by value MUST be [SimpleType] so Vala matches
 * raylib's C ABI.
 *
 * Reference: https://www.raylib.com/cheatsheet/cheatsheet.html
 */

[CCode (cheader_filename = "raylib.h", lower_case_cprefix = "")]
namespace Raylib {

    /* ---- Structs ------------------------------------------------------- */

    [SimpleType]
    [CCode (cname = "Vector2", has_type_id = false)]
    public struct Vector2 {
        public float x;
        public float y;
    }

    [SimpleType]
    [CCode (cname = "Color", has_type_id = false)]
    public struct Color {
        public uint8 r;
        public uint8 g;
        public uint8 b;
        public uint8 a;
    }

    [SimpleType]
    [CCode (cname = "Rectangle", has_type_id = false)]
    public struct Rectangle {
        public float x;
        public float y;
        public float width;
        public float height;
    }

    [SimpleType]
    [CCode (cname = "Texture2D", has_type_id = false)]
    public struct Texture2D {
        public uint id;
        public int width;
        public int height;
        public int mipmaps;
        public int format;
    }

    [SimpleType]
    [CCode (cname = "RenderTexture2D", has_type_id = false)]
    public struct RenderTexture2D {
        public uint id;
        public Texture2D texture;   // colour buffer
        public Texture2D depth;
    }

    [SimpleType]
    [CCode (cname = "AudioStream", has_type_id = false)]
    public struct AudioStream {
        public void* buffer;
        public void* processor;
        public uint  sampleRate;
        public uint  sampleSize;
        public uint  channels;
    }

    // Layout must match raylib's `struct Sound` exactly - it's passed by value.
    [SimpleType]
    [CCode (cname = "Sound", has_type_id = false)]
    public struct Sound {
        public AudioStream stream;
        public uint frameCount;
    }

    /* ---- Enums ------------------------------------------------------- */

    [CCode (cname = "int", cprefix = "FLAG_", has_type_id = false)]
    [Flags]
    public enum ConfigFlags {
        VSYNC_HINT,
        FULLSCREEN_MODE,
        WINDOW_RESIZABLE,
        WINDOW_UNDECORATED,
        WINDOW_HIDDEN,
        WINDOW_MINIMIZED,
        WINDOW_MAXIMIZED,
        WINDOW_HIGHDPI,
        MSAA_4X_HINT,
    }

    [CCode (cname = "int", cprefix = "KEY_", has_type_id = false)]
    public enum KeyboardKey {
        NULL,
        SPACE,
        ESCAPE,
        ENTER,
        BACKSPACE,
        RIGHT,
        LEFT,
        DOWN,
        UP,
        A, B, C, D, E, F, G, H, I, J, K, L, M,
        N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
        LEFT_SHIFT,
    }

    [CCode (cname = "int", cprefix = "GAMEPAD_BUTTON_", has_type_id = false)]
    public enum GamepadButton {
        UNKNOWN,
        LEFT_FACE_UP,
        LEFT_FACE_RIGHT,
        LEFT_FACE_DOWN,
        LEFT_FACE_LEFT,
        RIGHT_FACE_UP,
        RIGHT_FACE_RIGHT,
        RIGHT_FACE_DOWN,
        RIGHT_FACE_LEFT,
    }

    [CCode (cname = "int", cprefix = "GAMEPAD_AXIS_", has_type_id = false)]
    public enum GamepadAxis {
        LEFT_X,
        LEFT_Y,
        RIGHT_X,
        RIGHT_Y,
        LEFT_TRIGGER,
        RIGHT_TRIGGER,
    }

    [CCode (cname = "int", cprefix = "TEXTURE_FILTER_", has_type_id = false)]
    public enum TextureFilter {
        POINT,          // nearest-neighbour: crisp pixels
        BILINEAR,       // linear: smooth but soft
        TRILINEAR,
        ANISOTROPIC_4X,
        ANISOTROPIC_8X,
        ANISOTROPIC_16X,
    }

    /* ---- Colors (raylib.h #defines) --------------------------------- */

    [CCode (cname = "LIGHTGRAY")] public const Color LIGHTGRAY;
    [CCode (cname = "GRAY")]      public const Color GRAY;
    [CCode (cname = "DARKGRAY")]  public const Color DARKGRAY;
    [CCode (cname = "YELLOW")]    public const Color YELLOW;
    [CCode (cname = "GOLD")]      public const Color GOLD;
    [CCode (cname = "ORANGE")]    public const Color ORANGE;
    [CCode (cname = "PINK")]      public const Color PINK;
    [CCode (cname = "RED")]       public const Color RED;
    [CCode (cname = "MAROON")]    public const Color MAROON;
    [CCode (cname = "GREEN")]     public const Color GREEN;
    [CCode (cname = "LIME")]      public const Color LIME;
    [CCode (cname = "DARKGREEN")] public const Color DARKGREEN;
    [CCode (cname = "SKYBLUE")]   public const Color SKYBLUE;
    [CCode (cname = "BLUE")]      public const Color BLUE;
    [CCode (cname = "DARKBLUE")]  public const Color DARKBLUE;
    [CCode (cname = "PURPLE")]    public const Color PURPLE;
    [CCode (cname = "VIOLET")]    public const Color VIOLET;
    [CCode (cname = "DARKPURPLE")] public const Color DARKPURPLE;
    [CCode (cname = "MAGENTA")]   public const Color MAGENTA;
    [CCode (cname = "WHITE")]     public const Color WHITE;
    [CCode (cname = "BLACK")]     public const Color BLACK;
    [CCode (cname = "BLANK")]     public const Color BLANK;
    [CCode (cname = "RAYWHITE")]  public const Color RAYWHITE;

    /* ---- Window & lifecycle ---------------------------------------- */

    [CCode (cname = "InitWindow")]
    public void init_window (int width, int height, string title);
    [CCode (cname = "CloseWindow")]
    public void close_window ();
    [CCode (cname = "WindowShouldClose")]
    public bool window_should_close ();
    [CCode (cname = "SetTargetFPS")]
    public void set_target_fps (int fps);
    [CCode (cname = "SetConfigFlags")]
    public void set_config_flags (ConfigFlags flags);
    [CCode (cname = "SetExitKey")]
    public void set_exit_key (KeyboardKey key);
    [CCode (cname = "GetScreenWidth")]
    public int get_screen_width ();
    [CCode (cname = "GetScreenHeight")]
    public int get_screen_height ();
    [CCode (cname = "SetWindowSize")]
    public void set_window_size (int width, int height);
    [CCode (cname = "SetWindowPosition")]
    public void set_window_position (int x, int y);
    [CCode (cname = "ToggleFullscreen")]
    public void toggle_fullscreen ();

    /* ---- Monitors ------------------------------------------------------ */

    [CCode (cname = "GetMonitorCount")]
    public int get_monitor_count ();
    [CCode (cname = "GetCurrentMonitor")]
    public int get_current_monitor ();
    [CCode (cname = "GetMonitorWidth")]
    public int get_monitor_width (int monitor);
    [CCode (cname = "GetMonitorHeight")]
    public int get_monitor_height (int monitor);

    /* ---- Filesystem -------------------------------------------------- */

    [CCode (cname = "GetApplicationDirectory")]
    public unowned string get_application_directory ();
    [CCode (cname = "FileExists")]
    public bool file_exists (string file_name);
    [CCode (cname = "TakeScreenshot")]
    public void take_screenshot (string file_name);

    /* ---- Frame timing -------------------------------------------------- */

    [CCode (cname = "GetFrameTime")]
    public float get_frame_time ();
    [CCode (cname = "GetTime")]
    public double get_time ();
    [CCode (cname = "GetFPS")]
    public int get_fps ();

    /* ---- Drawing ----------------------------------------------------- */

    [CCode (cname = "BeginDrawing")]
    public void begin_drawing ();
    [CCode (cname = "EndDrawing")]
    public void end_drawing ();
    [CCode (cname = "ClearBackground")]
    public void clear_background (Color color);

    [CCode (cname = "DrawRectangle")]
    public void draw_rectangle (int x, int y, int w, int h, Color color);
    [CCode (cname = "DrawRectangleRec")]
    public void draw_rectangle_rec (Rectangle rec, Color color);
    [CCode (cname = "DrawRectangleV")]
    public void draw_rectangle_v (Vector2 position, Vector2 size, Color color);
    [CCode (cname = "DrawRectangleLinesEx")]
    public void draw_rectangle_lines_ex (Rectangle rec, float thick, Color color);
    [CCode (cname = "DrawCircleV")]
    public void draw_circle_v (Vector2 center, float radius, Color color);
    [CCode (cname = "DrawCircle")]
    public void draw_circle (int centerX, int centerY, float radius, Color color);
    [CCode (cname = "DrawLineEx")]
    public void draw_line_ex (Vector2 start, Vector2 end, float thick, Color color);
    [CCode (cname = "DrawTriangle")]
    public void draw_triangle (Vector2 v1, Vector2 v2, Vector2 v3, Color color);
    [CCode (cname = "DrawPixelV")]
    public void draw_pixel_v (Vector2 position, Color color);

    [CCode (cname = "DrawText")]
    public void draw_text (string text, int x, int y, int font_size, Color color);
    [CCode (cname = "MeasureText")]
    public int measure_text (string text, int font_size);
    [CCode (cname = "DrawFPS")]
    public void draw_fps (int x, int y);

    /* ---- Color helpers ---------------------------------------------- */

    [CCode (cname = "Fade")]
    public Color fade (Color color, float alpha);
    [CCode (cname = "ColorAlpha")]
    public Color color_alpha (Color color, float alpha);

    /* ---- Input: keyboard ---------------------------------------------- */

    [CCode (cname = "IsKeyDown")]
    public bool is_key_down (KeyboardKey key);
    [CCode (cname = "IsKeyPressed")]
    public bool is_key_pressed (KeyboardKey key);
    [CCode (cname = "IsKeyReleased")]
    public bool is_key_released (KeyboardKey key);
    [CCode (cname = "GetCharPressed")]
    public int get_char_pressed ();

    /* ---- Input: gamepad -------------------------------------------- */

    [CCode (cname = "IsGamepadAvailable")]
    public bool is_gamepad_available (int gamepad);
    [CCode (cname = "IsGamepadButtonDown")]
    public bool is_gamepad_button_down (int gamepad, GamepadButton button);
    [CCode (cname = "IsGamepadButtonPressed")]
    public bool is_gamepad_button_pressed (int gamepad, GamepadButton button);
    [CCode (cname = "GetGamepadAxisMovement")]
    public float get_gamepad_axis_movement (int gamepad, GamepadAxis axis);

    /* ---- Collision ------------------------------------------------- */

    [CCode (cname = "CheckCollisionRecs")]
    public bool check_collision_recs (Rectangle rec1, Rectangle rec2);
    [CCode (cname = "CheckCollisionCircles")]
    public bool check_collision_circles (Vector2 c1, float r1, Vector2 c2, float r2);
    [CCode (cname = "CheckCollisionCircleRec")]
    public bool check_collision_circle_rec (Vector2 center, float radius, Rectangle rec);
    [CCode (cname = "CheckCollisionPointRec")]
    public bool check_collision_point_rec (Vector2 point, Rectangle rec);

    /* ---- Random ----------------------------------------------------- */

    [CCode (cname = "GetRandomValue")]
    public int get_random_value (int min, int max);
    [CCode (cname = "SetRandomSeed")]
    public void set_random_seed (uint seed);

    /* ---- Textures (headroom for real sprites) --------------------- */

    [CCode (cname = "LoadTexture")]
    public Texture2D load_texture (string file_name);
    [CCode (cname = "UnloadTexture")]
    public void unload_texture (Texture2D texture);
    [CCode (cname = "IsTextureValid")]
    public bool is_texture_valid (Texture2D texture);
    [CCode (cname = "SetTextureFilter")]
    public void set_texture_filter (Texture2D texture, TextureFilter filter);

    // Render-to-texture (used for the fixed-resolution scaled backbuffer).
    [CCode (cname = "LoadRenderTexture")]
    public RenderTexture2D load_render_texture (int width, int height);
    [CCode (cname = "UnloadRenderTexture")]
    public void unload_render_texture (RenderTexture2D target);
    [CCode (cname = "IsRenderTextureValid")]
    public bool is_render_texture_valid (RenderTexture2D target);
    [CCode (cname = "BeginTextureMode")]
    public void begin_texture_mode (RenderTexture2D target);
    [CCode (cname = "EndTextureMode")]
    public void end_texture_mode ();
    [CCode (cname = "DrawTextureV")]
    public void draw_texture_v (Texture2D texture, Vector2 position, Color tint);
    [CCode (cname = "DrawTextureRec")]
    public void draw_texture_rec (Texture2D texture, Rectangle source, Vector2 position, Color tint);
    [CCode (cname = "DrawTexturePro")]
    public void draw_texture_pro (Texture2D texture, Rectangle source, Rectangle dest, Vector2 origin, float rotation, Color tint);

    /* ---- Audio (headroom for SFX/music) ------------------------------- */

    [CCode (cname = "InitAudioDevice")]
    public void init_audio_device ();
    [CCode (cname = "CloseAudioDevice")]
    public void close_audio_device ();
    [CCode (cname = "IsAudioDeviceReady")]
    public bool is_audio_device_ready ();
    [CCode (cname = "SetMasterVolume")]
    public void set_master_volume (float volume);
    [CCode (cname = "LoadSound")]
    public Sound load_sound (string file_name);
    [CCode (cname = "LoadSoundAlias")]
    public Sound load_sound_alias (Sound source);
    [CCode (cname = "IsSoundValid")]
    public bool is_sound_valid (Sound sound);
    [CCode (cname = "UnloadSound")]
    public void unload_sound (Sound sound);
    [CCode (cname = "UnloadSoundAlias")]
    public void unload_sound_alias (Sound alias);
    [CCode (cname = "PlaySound")]
    public void play_sound (Sound sound);
    [CCode (cname = "IsSoundPlaying")]
    public bool is_sound_playing (Sound sound);
    [CCode (cname = "SetSoundVolume")]
    public void set_sound_volume (Sound sound, float volume);
    [CCode (cname = "SetSoundPitch")]
    public void set_sound_pitch (Sound sound, float pitch);
}
