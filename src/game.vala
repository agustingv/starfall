/*
 * Game: the application shell. Owns the window and the fixed-resolution
 * backbuffer, runs the fixed-timestep loop, and delegates update/draw to the
 * current Screen. Screens call back here to change screen or quit.
 */

namespace Starfall {

    public class Game : Object {
        Raylib.RenderTexture2D scene;   // fixed-resolution backbuffer
        Screen screen;
        bool   quitting;

        public void run () {
            Raylib.set_config_flags (Raylib.ConfigFlags.VSYNC_HINT | Raylib.ConfigFlags.WINDOW_RESIZABLE);
            Raylib.init_window (Config.SCREEN_W, Config.SCREEN_H, "Starfall");
            Raylib.set_exit_key (Raylib.KeyboardKey.NULL);   // Esc is the in-game pause key
            Raylib.init_audio_device ();
            Raylib.set_master_volume (0.7f);
            Raylib.set_target_fps (240);   // render cap; simulation runs at TICK

            size_window_to_monitor ();

            scene = Raylib.load_render_texture (Config.SCREEN_W, Config.SCREEN_H);
            Raylib.set_texture_filter (scene.texture, Raylib.TextureFilter.POINT);

            Assets.instance ();   // warm-load sprites, sounds and scores up front
            Audio.instance ();
            HighScores.instance ();

            screen = new TitleScreen (this);
            screen.on_enter ();

            double acc = 0.0;
            while (!Raylib.window_should_close () && !quitting) {
                if (Raylib.is_key_pressed (Raylib.KeyboardKey.F))
                    Raylib.toggle_fullscreen ();

                // Edge-triggered input once per frame, so no key press is lost
                // between fixed-step ticks.
                screen.handle_input ();

                acc += Raylib.get_frame_time ();
                if (acc > 0.25) acc = 0.25;            // avoid the spiral of death
                while (acc >= Config.TICK) {
                    screen.update (Config.TICK);
                    acc -= Config.TICK;
                }
                render ();
            }

            Raylib.unload_render_texture (scene);
            Raylib.close_audio_device ();
            Raylib.close_window ();
        }

        /* ---- Screen transitions (called by screens) ---------------------- */

        public void start_new_game () {
            switch_to (new PlayScreen (this));
        }

        public void goto_title () {
            switch_to (new TitleScreen (this));
        }

        public void goto_scores () {
            switch_to (new ScoreScreen (this));
        }

        public void request_quit () {
            quitting = true;
        }

        void switch_to (Screen next) {
            screen = next;
            screen.on_enter ();
        }

        /* ---- Rendering -------------------------------------------------- */

        void render () {
            Raylib.begin_texture_mode (scene);
            Raylib.clear_background (Palette.BG);
            screen.draw ();
            Raylib.end_texture_mode ();
            present ();
        }

        /* Blit the backbuffer to the window, scaled to fit and centred, with
         * black bars filling the remainder. */
        void present () {
            int sw = Raylib.get_screen_width ();
            int sh = Raylib.get_screen_height ();
            float scale = minf ((float) sw / Config.SCREEN_W, (float) sh / Config.SCREEN_H);

            float dw = Config.SCREEN_W * scale;
            float dh = Config.SCREEN_H * scale;

            // Negative source height flips the render texture back to top-down.
            Raylib.Rectangle src = { 0.0f, 0.0f, (float) Config.SCREEN_W, -(float) Config.SCREEN_H };
            Raylib.Rectangle dst = { (sw - dw) * 0.5f, (sh - dh) * 0.5f, dw, dh };

            Raylib.begin_drawing ();
            Raylib.clear_background (Palette.BLACK);
            Raylib.draw_texture_pro (scene.texture, src, dst, { 0.0f, 0.0f }, 0.0f, Palette.WHITE);
            Raylib.end_drawing ();
        }

        /* Resize the window to the largest 2:3 portrait rectangle that fits
         * comfortably on the current monitor, then centre it. */
        void size_window_to_monitor () {
            int mon = Raylib.get_current_monitor ();
            int mw  = Raylib.get_monitor_width (mon);
            int mh  = Raylib.get_monitor_height (mon);
            if (mw <= 0 || mh <= 0)
                return;

            float aspect = (float) Config.SCREEN_W / (float) Config.SCREEN_H;
            int win_h = (int) (mh * 0.9f);
            int win_w = (int) (win_h * aspect);
            if (win_w > mw * 0.9f) {
                win_w = (int) (mw * 0.9f);
                win_h = (int) (win_w / aspect);
            }

            Raylib.set_window_size (win_w, win_h);
            Raylib.set_window_position ((mw - win_w) / 2, (mh - win_h) / 2);
        }
    }
}
