import d2d;
import gpu;
import cpu;

Chip8 chip;


void main() {

    chip = new Chip8();
    chip.loadRom("roms/brix.rom");
    setupGraphics();

}

void setupGraphics() {
    immutable width = 64 * 30;
    Display display = new Display(width, width / 2, SDL_WINDOW_SHOWN, 0, "Chip-8 Emulator", null);
    display.framerate(120);
    display.screen = new RenderScreen(display, width / 64, chip);
    display.run();
}
