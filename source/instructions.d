import std.random;
import cpu;

pure void function(Chip8 chip)[] getInstructionTable() {
    return [&.clr, &.ret, &.jpi, &.call, &.sei, &.snei, &.se, &.ldi,
        &.addi, &.ld, &.or, &.and, &.xor, &.add, &.sub, &.shr, &.subn,
        &.shl, &.sne, &.lda, &.jp, &.rnd, &.drw, &.skp, &.sknp, &.lddt,
        &.ldkp, &.dtld, &.ldst, &.adda, &.ldf, &.ldb, &.ldar, &.ldra];
}

pure int[ushort] getOpMap() {
    int[ushort] cached;
    for (ushort i = 0; i < 0xFFFF; i++) {
        cached[i] = getInstruction(i);
    }
    return cached;
}
// convenince variables to save a keystroke
immutable ubyte A = 0xA;
immutable ubyte B = 0xB;
immutable ubyte C = 0xC;
immutable ubyte D = 0xD;
immutable ubyte E = 0xE;
immutable ubyte F = 0xF;
immutable ubyte x = 255; // x is a placeholder, it is used when it can match any value, 255 is chosen as it is out of range, b1-b4 are really just 4bit numbers

void clr(Chip8 chip) {
    // 00E0 - CLS: Clear the display
    chip.pixels = false;
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

void ldi(Chip8 chip) {
    // 6xkk - LD Vx, byte: Set Vx = kk.
    chip.V[((chip.op & 0x0F00) >> 8)] = cast(ubyte)(chip.op & 0x00FF);
}

void addi(Chip8 chip) {
    // 7xkk - ADD Vx, byte: Set Vx = Vx + kk
    chip.V[((chip.op & 0x0F00) >> 8)] += cast(ubyte)(chip.op & 0x00FF);
}

void ld(Chip8 chip) {
    // 8xy0 - LD Vx, Vy: Set Vx = Vy.
    chip.V[((chip.op & 0x0F00) >> 8)] = chip.V[((chip.op & 0x00F0) >> 4)];
}

void or(Chip8 chip) {
    // 8xy1 - OR Vx, Vy: Set Vx = Vx OR Vy.
    chip.V[((chip.op & 0x0F00) >> 8)] |= chip.V[((chip.op & 0x00F0) >> 4)];
}

void and(Chip8 chip) {
    // 8xy2 - AND Vx, Vy: Set Vx = Vx AND Vy
    chip.V[((chip.op & 0x0F00) >> 8)] &= chip.V[((chip.op & 0x00F0) >> 4)];
}

void xor(Chip8 chip) {
    // 8xy3 - XOR Vx, Vy: Set Vx = Vx XOR Vy.
    chip.V[((chip.op & 0x0F00) >> 8)] ^= chip.V[((chip.op & 0x00F0) >> 4)];
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
    chip.V[F] = (chip.V[((chip.op & 0x0F00) >> 8)] & 1) ? 1 : 0;
    chip.V[((chip.op & 0x0F00) >> 8)] >>= 1;
}

void subn(Chip8 chip) {
    // 8xy7 - SUBN Vx, Vy: Set Vx = Vy - Vx,
    chip.V[F] = chip.V[((chip.op & 0x00F0) >> 4)] > chip.V[((chip.op & 0x0F00) >> 8)] ? 1 : 0;
    chip.V[((chip.op & 0x0F00) >> 8)] = cast(ubyte)(chip.V[((chip.op & 0x00F0) >> 4)] - chip.V[((chip.op & 0x0F00) >> 8)]);
}

void shl(Chip8 chip) {
    // 8xyE - SHL Vx {, Vy}: Set Vx = Vx SHL 1.
    chip.V[F] = (chip.V[((chip.op & 0x0F00) >> 8)] & 0b10000000) >> 7;
    chip.V[((chip.op & 0x0F00) >> 8)] <<= 1;
}

void sne(Chip8 chip) {
    // 9xy0 - SNE Vx, Vy: Skip next instruction if Vx != Vy
    if (chip.V[((chip.op & 0x0F00) >> 8)] != chip.V[((chip.op & 0x00F0) >> 4)]) {
        chip.pc += 2;
    }
}

void lda(Chip8 chip) {
    // Annn - LD I, addr: Set I = nnn.
    chip.I = chip.op & 0x0FFF;
}

void jp(Chip8 chip) {
    // Bnnn - JP V0, addr: Jump to location nnn + V0.
    chip.pc = cast(ushort)(chip.V[0] + chip.op & 0x0FFF);
}

void rnd(Chip8 chip) {
    // Cxkk - RND Vx, byte: Set Vx = random byte AND kk.
    chip.V[((chip.op & 0x0F00) >> 8)] = cast(ubyte)(uniform(0, 256) & chip.op & 0x00FF);
}

void drw(Chip8 chip) {
    // Dxyn - DRW Vx, Vy, nibble: Display n-byte sprite starting at memory location I at (chip.Vx, Vy), set VF = collision
    chip.V[F] = chip.drawSprite(chip.V[((chip.op & 0x0F00) >> 8)],
            chip.V[((chip.op & 0x00F0) >> 4)], (chip.op & 0x000F)) ? 1 : 0;
}

void skp(Chip8 chip) {
    // Ex9E - SKP Vx: Skip next instruction if key with the value of Vx is pressed.
    if (chip.keys[chip.V[((chip.op & 0x0F00) >> 8)]]) {
        chip.pc += 2;
    }
}

void sknp(Chip8 chip) {
    // ExA1 - SKNP Vx: Skip next instruction if key with the value of Vx is not pressed
    if (!chip.keys[chip.V[((chip.op & 0x0F00) >> 8)]]) {
        chip.pc += 2;
    }
}

void lddt(Chip8 chip) {
    // Fx07 - LD Vx, DT: Set Vx = delay timer value.
    chip.V[((chip.op & 0x0F00) >> 8)] = chip.delay_timer;
}

void ldkp(Chip8 chip) {
    // Fx0A - LD Vx, K: Wait for a key press, store the value of the key in Vx.
    if (chip.getPress() == 255) {
        chip.pc -= 2;
        chip.printKeys();
    }
    else {
        chip.V[((chip.op & 0x0F00) >> 8)] = chip.getPress();
    }
}

void dtld(Chip8 chip) {
    // Fx15 - LD DT, Vx: Set delay timer = Vx.
    chip.delay_timer = chip.V[((chip.op & 0x0F00) >> 8)];
}

void ldst(Chip8 chip) {
    // Fx18 - LD ST, Vx: Set sound timer = Vx.
    chip.sound_timer = chip.V[((chip.op & 0x0F00) >> 8)];
}

void adda(Chip8 chip) {
    // Fx1E - ADD I, Vx: Set I = I + Vx.
    chip.I += chip.V[((chip.op & 0x0F00) >> 8)];
}

void ldf(Chip8 chip) {
    // Fx29 - LD F, Vx: Set I = location of sprite for digit Vx.
    chip.I = 5 * chip.V[((chip.op & 0x0F00) >> 8)];
}

void ldb(Chip8 chip) {
    // Fx33 - LD B, Vx: Store BCD representation of Vx in memory locations I, I+1, and I+2.
    chip.memory[chip.I] = cast(ubyte)((chip.V[((chip.op & 0x0F00) >> 8)] / 100) % 10);
    chip.memory[chip.I + 1] = cast(ubyte)((chip.V[((chip.op & 0x0F00) >> 8)] / 10) % 10);
    chip.memory[chip.I + 2] = cast(ubyte)((chip.V[((chip.op & 0x0F00) >> 8)]) % 10);

}

void ldar(Chip8 chip) {
    // Fx55 - LD [I], Vx: Store registers V0 through Vx in memory starting at location I
    for (int i = 0; i < ((chip.op & 0x0F00) >> 8); i++) {
        chip.memory[chip.I++] = chip.V[i];
    }
}

void ldra(Chip8 chip) {
    // Fx65 - LD Vx, [I]: Read registers V0 through Vx from memory starting at location I.
    for (int i = 0; i < ((chip.op & 0x0F00) >> 8); i++) {
        chip.V[i] = chip.memory[chip.I++];
    }
}

pure bool matches(ushort op, ubyte b1, ubyte b2, ubyte b3, ubyte b4) {
    if ((op & 0x000F) != b4 && b4 != x)
        return false;
    if (((op & 0x00F0) >> 4) != b3 && b3 != x)
        return false;
    if (((op & 0x0F00) >> 8) != b2 && b2 != x)
        return false;
    if (((op & 0xF000) >> 12) != b1 && b1 != x)
        return false;
    return true;
}

pure int getInstruction(const ushort op) {
    if (matches(op, 0, 0, E, 0)) { // 00E0 - CLS: Clear the display
        return 0;
    }
    else if (matches(op, 0, 0, E, E)) { // 00EE - RET: Return from a subroutine.
        return 1;
    }
    else if (matches(op, 1, x, x, x)) { // 1nnn - JP addr: Jump to location nnn
        return 2;
    }
    else if (matches(op, 2, x, x, x)) { // 2nnn - CALL addr: Call subroutine at nnn
        return 3;
    }
    else if (matches(op, 3, x, x, x)) { // 3xkk - SE Vx, byte: Skip next instruction if Vx = kk.
        return 4;
    }
    else if (matches(op, 4, x, x, x)) { // 4xkk - SNE Vx, byte: Skip next instruction if Vx != kk
        return 5;
    }
    else if (matches(op, 5, x, x, 0)) { // 5xy0 - SE Vx, Vy: Skip next instruction if Vx = Vy
        return 6;
    }
    else if (matches(op, 6, x, x, x)) { // 6xkk - LD Vx, byte: Set Vx = kk.
        return 7;
    }
    else if (matches(op, 7, x, x, x)) { // 7xkk - ADD Vx, byte: Set Vx = Vx + kk
        return 8;
    }
    else if (matches(op, 8, x, x, 0)) { // 8xy0 - LD Vx, Vy: Set Vx = Vy.
        return 9;
    }
    else if (matches(op, 8, x, x, 1)) { // 8xy1 - OR Vx, Vy: Set Vx = Vx OR Vy.
        return 10;
    }
    else if (matches(op, 8, x, x, 2)) { // 8xy2 - AND Vx, Vy: Set Vx = Vx AND Vy
        return 11;
    }
    else if (matches(op, 8, x, x, 3)) { // 8xy3 - XOR Vx, Vy: Set Vx = Vx XOR Vy.
        return 12;
    }
    else if (matches(op, 8, x, x, 4)) { // 8xy4 - ADD Vx, Vy: Set Vx = Vx + Vy, set VF = carry.
        return 13;
    }
    else if (matches(op, 8, x, x, 5)) { // 8xy5 - SUB Vx, Vy: Set Vx = Vx - Vy, set VF = NOT borrow.
        return 14;
    }
    else if (matches(op, 8, x, x, 6)) { // 8xy6 - SHR Vx {, Vy}: Set Vx = Vx SHR 1.
        return 15;
    }
    else if (matches(op, 8, x, x, 7)) { // 8xy7 - SUBN Vx, Vy: Set Vx = Vy - Vx,
        return 16;
    }
    else if (matches(op, 8, x, x, E)) { // 8xyE - SHL Vx {, Vy}: Set Vx = Vx SHL 1.
        return 17;
    }
    else if (matches(op, 9, x, x, 0)) { // 9xy0 - SNE Vx, Vy: Skip next instruction if Vx != Vy
        return 18;
    }
    else if (matches(op, A, x, x, x)) { // Annn - LD I, addr: Set I = nnn.
        return 19;
    }
    else if (matches(op, B, x, x, x)) { // Bnnn - JP V0, addr: Jump to location nnn + V0.
        return 20;
    }
    else if (matches(op, C, x, x, x)) { // Cxkk - RND Vx, byte: Set Vx = random byte AND kk.
        return 21;
    }
    else if (matches(op, D, x, x, x)) { // Dxyn - DRW Vx, Vy, nibble: Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision
        return 22;
    }
    else if (matches(op, E, x, 9, E)) { // Ex9E - SKP Vx: Skip next instruction if key with the value of Vx is pressed.
        return 23;
    }
    else if (matches(op, E, x, A, 1)) { // ExA1 - SKNP Vx: Skip next instruction if key with the value of Vx is not pressed
        return 24;
    }
    else if (matches(op, F, x, 0, 7)) { // Fx07 - LD Vx, DT: Set Vx = delay timer value.
        return 25;
    }
    else if (matches(op, F, x, 0, A)) { // Fx0A - LD Vx, K: Wait for a key press, store the value of the key in Vx.
        return 26;
    }
    else if (matches(op, F, x, 1, 5)) { // Fx15 - LD DT, Vx: Set delay timer = Vx.
        return 27;
    }
    else if (matches(op, F, x, 1, 8)) { // Fx18 - LD ST, Vx: Set sound timer = Vx.
        return 28;
    }
    else if (matches(op, F, x, 1, E)) { // Fx1E - ADD I, Vx: Set I = I + Vx.
        return 29;
    }
    else if (matches(op, F, x, 2, 9)) { // Fx29 - LD F, Vx: Set I = location of sprite for digit Vx.
        return 30;
    }
    else if (matches(op, F, x, 3, 3)) { // Fx33 - LD B, Vx: Store BCD representation of Vx in memory locations I, I+1, and I+2.
        return 31;
    }
    else if (matches(op, F, x, 5, 5)) { // Fx55 - LD [I], Vx: Store registers V0 through Vx in memory starting at location I
        return 32;
    }
    else if (matches(op, F, x, 6, 5)) { // Fx65 - LD Vx, [I]: Read registers V0 through Vx from memory starting at location I.
        return 33;
    }

    return 35; // larger then array so should call a crash if this gets exucuted
}

unittest {
    // tests drawing functions, and rnd, cause idk what to group that with

    Chip8 chip = new Chip8();

    // rnd(chip);
    // drw(chip);

    // ldf(chip);
    // ldb(chip);

    clr(chip);
    for (int i = 0; i < 32 * 64; i++) {
        assert(!chip.pixels[i]);
    }
}

unittest {
    // test control flow functions
    Chip8 chip = new Chip8();
    // ret(chip);
    // jpi(chip);
    // call(chip);
    // sei(chip);
    // snei(chip);
    // se(chip);
    // sne(chip);
    // jp(chip);
}

unittest {
    // test key press functions
    Chip8 chip = new Chip8();
    // skp(chip);
    // sknp(chip);
    // ldkp(chip);
}

unittest {
    // test timer functions
    Chip8 chip = new Chip8();
    // lddt(chip);
    // dtld(chip);
    // ldst(chip);
}

unittest {

    Chip8 chip = new Chip8();
    // addi(chip);
    // add(chip);
    // sub(chip);
    // subn(chip);
    // adda(chip);
}

unittest {
    Chip8 chip = new Chip8();
    // or(chip);
    // and(chip);
    // xor(chip);
    // shl(chip);
    // shr(chip);
}

unittest {
    Chip8 chip = new Chip8();
    // ldi(chip);
    // ld(chip);
    // lda(chip);

    // ldar(chip);
    // ldra(chip);
}
