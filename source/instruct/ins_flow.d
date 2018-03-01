module instruct.ins_flow;
import cpu;

unittest {
    // test control flow functions
    Chip8 chip = new Chip8();
    chip.pc = 205;
    chip.op = 0x2333;
    call(chip);
    assert(chip.pc == 0x0333);

    ret(chip);
    assert(chip.pc == 205);

    // jpi(chip);

    // sei(chip);
    // snei(chip);
    // se(chip);
    // sne(chip);
    // jp(chip);
}

void ret(Chip8 chip) {
    // 00EE - RET: Return from a subroutine.
    chip.pc = chip.stack[--chip.sp];
}

void jpi(Chip8 chip) {
    // 1nnn - JP addr: Jump to location nnn
    chip.pc = chip.op & 0x0FFF;
}

void call(Chip8 chip) {
    // 2nnn - CALL addr: Call subroutine at nnn
    chip.stack[chip.sp++] = chip.pc;
    chip.pc = chip.op & 0x0FFF;
}

void sei(Chip8 chip) {
    // 3xkk - SE Vx, byte: Skip next instruction if Vx = kk.
    if (chip.V[((chip.op & 0x0F00) >> 8)] == (chip.op & 0x00FF)) {
        chip.pc += 2;
    }
}

void snei(Chip8 chip) {
    // 4xkk - SNE Vx, byte: Skip next instruction if Vx != kk
    if (chip.V[((chip.op & 0x0F00) >> 8)] != (chip.op & 0x00FF)) {
        chip.pc += 2;
    }
}

void se(Chip8 chip) {
    // 5xy0 - SE Vx, Vy: Skip next instruction if Vx = Vy
    if (chip.V[((chip.op & 0x0F00) >> 8)] == chip.V[((chip.op & 0x00F0) >> 4)]) {
        chip.pc += 2;
    }
}

void sne(Chip8 chip) {
    // 9xy0 - SNE Vx, Vy: Skip next instruction if Vx != Vy
    if (chip.V[((chip.op & 0x0F00) >> 8)] != chip.V[((chip.op & 0x00F0) >> 4)]) {
        chip.pc += 2;
    }
}
void jp(Chip8 chip) {
    // Bnnn - JP V0, addr: Jump to location nnn + V0.
    chip.pc = cast(ushort)(chip.V[0] + chip.op & 0x0FFF);
}
