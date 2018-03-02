module instruct.ins_timers;
import cpu;

unittest {
    // test timer functions
    Chip8 chip = new shared Chip8();
    // lddt(chip);
    // dtld(chip);
    // ldst(chip);
}


void lddt(shared Chip8 chip) {
    // Fx07 - LD Vx, DT: Set Vx = delay timer value.
    chip.V[((chip.op & 0x0F00) >> 8)] = chip.delay_timer;
}



void dtld(shared Chip8 chip) {
    // Fx15 - LD DT, Vx: Set delay timer = Vx.
    chip.delay_timer = chip.V[((chip.op & 0x0F00) >> 8)];
}

void ldst(shared Chip8 chip) {
    // Fx18 - LD ST, Vx: Set sound timer = Vx.
    chip.sound_timer = chip.V[((chip.op & 0x0F00) >> 8)];
}
