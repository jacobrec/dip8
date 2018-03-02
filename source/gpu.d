import d2d;
import cpu;
import std.datetime;
import core.sync.mutex;

import std.datetime.stopwatch : benchmark, StopWatch;
import std.stdio;
/**
 * The screen on which to draw some shapes
 */
class RenderScreen : Screen {
    static immutable int height = 32;
    static immutable int width = 64;

    int pixSize;

    void function() onframe;

    shared Chip8 chip;

    auto foreground = PredefinedColor.WHITE;
    auto background = PredefinedColor.BLACK;

    this(Display container, int pixelsPerPixel,shared Chip8 chip) {
        super(container);
        this.pixSize = pixelsPerPixel;
        this.chip = chip;

    }
    // dfmt off
    SDL_Keycode[16] keymap = [
        SDLK_1, SDLK_2, SDLK_3, SDLK_4,
        SDLK_q, SDLK_w, SDLK_e, SDLK_r,
        SDLK_a, SDLK_s, SDLK_d, SDLK_f,
        SDLK_z, SDLK_x, SDLK_c, SDLK_v
    ];
    // dfmt on

    void handleEvent(SDL_Event event) {
        for (int i = 0; i < 16; i++) {
            this.chip.keys[i] = container.keyboard.allKeys[keymap[i]].isPressed();
        }
    }

    override void draw() {
        // clear the screen
        this.container.renderer.clear(PredefinedColor.BLACK);

        // Draw the pixels
        this.chip.pixelMutex.lock_nothrow();
        for (int i = 0; i < width * height; i++) {
            if (this.chip.pixels[i]) {
                this.container.renderer.fillRect(new iRectangle(this.pixSize * (i % width),
                        this.pixSize * (i / width), this.pixSize, this.pixSize), this.foreground);
            }
        }
        this.chip.pixelMutex.unlock_nothrow();
    }



    int i = 0;
    int n = 0;
    override void onFrame() {
        // for(int i = 0; i < 9; i++){
        //     this.chip.cycle540hz();
        // }
        // this.chip.cycle60hz();

        if (this.chip.sound_timer) {
            this.foreground = PredefinedColor.BLACK;
            this.background = PredefinedColor.WHITE;
        }
        else {
            this.foreground = PredefinedColor.WHITE;
            this.background = PredefinedColor.BLACK;
        }
    }
}
