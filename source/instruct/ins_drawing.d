module instruct.ins_drawing;
import cpu;
import instruct.instructions;
import std.random;

unittest {
    // tests drawing functions, and rnd, cause idk what to group that with

    Chip8 chip = new shared Chip8();

    // rnd(chip);
    // drw(chip);

    // ldf(chip);
    // ldb(chip);

    clr(chip);
    for (int i = 0; i < 32 * 64; i++) {
        assert(!chip.pixels[i]);
    }
}

void clr(shared Chip8 chip) {
    // 00E0 - CLS: Clear the display
    chip.pixels = false;
}

void rnd(shared Chip8 chip) {
    // Cxkk - RND Vx, byte: Set Vx = random byte AND kk.
    chip.V[((chip.op & 0x0F00) >> 8)] = cast(ubyte)(uniform(0, 256) & chip.op & 0x00FF);
}

void drw(shared Chip8 chip) {
    // Dxyn - DRW Vx, Vy, nibble: Display n-byte sprite starting at memory location I at (chip.Vx, Vy), set VF = collision
    chip.V[F] = chip.drawSprite(chip.V[((chip.op & 0x0F00) >> 8)],
            chip.V[((chip.op & 0x00F0) >> 4)], (chip.op & 0x000F)) ? 1 : 0;
}

void ldf(shared Chip8 chip) {
    // Fx29 - LD F, Vx: Set I = location of sprite for digit Vx.
    chip.I = 5 * chip.V[((chip.op & 0x0F00) >> 8)];
}

void ldb(shared Chip8 chip) {
    // Fx33 - LD B, Vx: Store BCD representation of Vx in memory locations I, I+1, and I+2.
    chip.memory[chip.I] = cast(ubyte)((chip.V[((chip.op & 0x0F00) >> 8)] / 100) % 10);
    chip.memory[chip.I + 1] = cast(ubyte)((chip.V[((chip.op & 0x0F00) >> 8)] / 10) % 10);
    chip.memory[chip.I + 2] = cast(ubyte)((chip.V[((chip.op & 0x0F00) >> 8)]) % 10);

}
