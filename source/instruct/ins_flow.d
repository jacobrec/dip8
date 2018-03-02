module instruct.ins_flow;
import cpu;
import std.format;

unittest {
    // test control flow functions
    Chip8 chip = new Chip8();
    void callRetTest(ushort i) {
        chip.pc = 0x205;
        chip.op = i;
        call(chip);
        assert(chip.pc == (i & 0x0FFF));
        assert(chip.sp == 1);

        ret(chip);
        assert(chip.pc == 0x205);
        assert(chip.sp == 0);
    }

    void jpiTest(ushort i) {
        chip.op = i;
        jpi(chip);
        assert(chip.pc == (i & 0x0FFF), format!"Failed when i is %x, pc is %x"(i, chip.pc));
    };
    void jpTest(ushort i) {
        chip.op = i;
        chip.V[0] = cast(byte) i;
        jp(chip);
        assert(chip.pc == (chip.V[0] + i & 0x0FFF), format!"Failed when i is %x, pc is %x"(i, chip.pc));
    };
    chip.pc = 0x200;
    for (ushort i = 0; i < 24; i++) {
        chip.op = 0x200 | i;
        call(chip);
    }
    assert(chip.pc == (0x0200 | 23), format!"%x, %d"(chip.pc,chip.pc));
    assert(chip.sp == 24);
    for (ushort i = 0; i < 24; i++) {
        assert(chip.pc == (0x0200 | (23-i)));
        assert(chip.sp == (24-i), format!"%x, %d"(chip.sp,chip.sp));
        ret(chip);
    }
    assert(chip.sp == 0);

    for (ushort i = 0; i < 0xFFF; i++) {
        jpiTest(0x1000 | i);
        callRetTest(0x2000 | i);
        jpTest(0xB000 | i);
    }

    // sei(chip);
    // snei(chip);
    // se(chip);
    // sne(chip);
}

void ret(Chip8 chip) {
    // 00EE - RET: Return from a subroutine.
    chip.pc = cast(ushort)(chip.stack[--chip.sp]);
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
