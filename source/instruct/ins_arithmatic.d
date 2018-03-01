module instruct.ins_arithmatic;
import cpu;
import instruct.instructions;

unittest {

    Chip8 chip = new Chip8();
    // addi(chip);
    // add(chip);
    // sub(chip);
    // subn(chip);
    // adda(chip);
    // shl(chip);
    // shr(chip);
}

void add(Chip8 chip) {
    // 8xy4 - ADD Vx, Vy: Set Vx = Vx + Vy, set VF = carry.
    immutable int sum = chip.V[((chip.op & 0x0F00) >> 8)] + chip.V[((chip.op & 0x00F0) >> 4)];
    if (sum > 255) {
        chip.V[F] = cast(ubyte)(sum - 255);
    }
    chip.V[((chip.op & 0x0F00) >> 8)] = cast(ubyte)(sum & 0xFF);
}

void sub(Chip8 chip) {
    // 8xy5 - SUB Vx, Vy: Set Vx = Vx - Vy, set VF = NOT borrow.
    chip.V[F] = chip.V[((chip.op & 0x0F00) >> 8)] > chip.V[((chip.op & 0x00F0) >> 4)] ? 1 : 0;
    chip.V[((chip.op & 0x0F00) >> 8)] -= chip.V[((chip.op & 0x00F0) >> 4)];
}

void shr(Chip8 chip) {
    // 8xy6 - SHR Vx {, Vy}: Set Vx = Vx SHR 1.
    chip.V[F] = (chip.V[((chip.op & 0x0F00) >> 8)] & 0x1) ? 1 : 0;
    chip.V[((chip.op & 0x0F00) >> 8)] >>= 1;
}

void subn(Chip8 chip) {
    // 8xy7 - SUBN Vx, Vy: Set Vx = Vy - Vx,
    chip.V[F] = chip.V[((chip.op & 0x00F0) >> 4)] > chip.V[((chip.op & 0x0F00) >> 8)] ? 1 : 0;
    chip.V[((chip.op & 0x0F00) >> 8)] = cast(ubyte)(
            chip.V[((chip.op & 0x00F0) >> 4)] - chip.V[((chip.op & 0x0F00) >> 8)]);
}

void shl(Chip8 chip) {
    // 8xyE - SHL Vx {, Vy}: Set Vx = Vx SHL 1.
    chip.V[F] = (chip.V[((chip.op & 0x0F00) >> 8)] & 0b10000000) >> 7;
    chip.V[((chip.op & 0x0F00) >> 8)] <<= 1;
}

void addi(Chip8 chip) {
    // 7xkk - ADD Vx, byte: Set Vx = Vx + kk
    chip.V[((chip.op & 0x0F00) >> 8)] += cast(ubyte)(chip.op & 0x00FF);
}

void adda(Chip8 chip) {
    // Fx1E - ADD I, Vx: Set I = I + Vx.
    chip.I += chip.V[((chip.op & 0x0F00) >> 8)];
}
