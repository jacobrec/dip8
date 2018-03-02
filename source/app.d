import d2d;
import std.datetime.stopwatch;
import std.concurrency : spawn;

import gpu;
import cpu;
shared Chip8 chip;
void main() {

    chip = new shared Chip8();
    chip.loadRom("roms/brix.rom");
    spawn(&graphicsThread);
    spawn(&cpuThread);
}

void graphicsThread() {
    immutable width = 64 * 30;
    Display display = new Display(width, width / 2, SDL_WINDOW_SHOWN, 0, "Chip-8 Emulator", null);
    display.screen = new RenderScreen(display, width / 64, chip);
    display.run();
}

void cpuThread() {
    StopWatch sw;
    sw.start();
    ulong count60; // do every 16667 useconds
    ulong count540; // do every 1852 useconds

    while (true) {
        if (sw.peek().total!"usecs" > count60 * 16667) {
            count60++;
            chip.cycle60hz();
        }
        if (sw.peek().total!"usecs" > count540 * 1852) {
            count540++;
            chip.cycle540hz();
        }
    }

}
