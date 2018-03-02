module instruct.ins_logical;
import cpu;

unittest {
    Chip8 chip = new shared Chip8();
    // or(chip);
    // and(chip);
    // xor(chip);

}
void or(shared Chip8 chip) {
    // 8xy1 - OR Vx, Vy: Set Vx = Vx OR Vy.
    chip.V[((chip.op & 0x0F00) >> 8)] |= chip.V[((chip.op & 0x00F0) >> 4)];
}

void and(shared Chip8 chip) {
    // 8xy2 - AND Vx, Vy: Set Vx = Vx AND Vy
    chip.V[((chip.op & 0x0F00) >> 8)] &= chip.V[((chip.op & 0x00F0) >> 4)];
}

void xor(shared Chip8 chip) {
    // 8xy3 - XOR Vx, Vy: Set Vx = Vx XOR Vy.
    chip.V[((chip.op & 0x0F00) >> 8)] ^= chip.V[((chip.op & 0x00F0) >> 4)];
}
