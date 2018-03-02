module instruct.ins_load;
import cpu;

unittest {
    Chip8 chip = new shared Chip8();
    // ldi(chip);
    // ld(chip);
    // lda(chip);

    // ldar(chip);
    // ldra(chip);
}


void ldi(shared Chip8 chip) {
    // 6xkk - LD Vx, byte: Set Vx = kk.
    chip.V[((chip.op & 0x0F00) >> 8)] = cast(ubyte)(chip.op & 0x00FF);
}

void ld(shared Chip8 chip) {
    // 8xy0 - LD Vx, Vy: Set Vx = Vy.
    chip.V[((chip.op & 0x0F00) >> 8)] = chip.V[((chip.op & 0x00F0) >> 4)];
}
void lda(shared Chip8 chip) {
    // Annn - LD I, addr: Set I = nnn.
    chip.I = chip.op & 0x0FFF;
}


void ldar(shared Chip8 chip) {
    // Fx55 - LD [I], Vx: Store registers V0 through Vx in memory starting at location I
    for (int i = 0; i < ((chip.op & 0x0F00) >> 8); i++) {
        chip.memory[chip.I++] = chip.V[i];
    }
}

void ldra(shared Chip8 chip) {
    // Fx65 - LD Vx, [I]: Read registers V0 through Vx from memory starting at location I.
    for (int i = 0; i < ((chip.op & 0x0F00) >> 8); i++) {
        chip.V[i] = chip.memory[chip.I++];
    }
}
