import std.random;

// dfmt off
ubyte[80] chip8_fontset = [
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80 // F
];
// dfmt on

class Chip8 {
    /*
        ## Memory Map ##
        0x000 ---- 0x1FF : Chip8 interpreter
        0x050 ---- 0x0A0 : Font set, 4x5 pixels [0-F]
        0x200 ---- 0xFFF : Program ROM and work RAM

    */
    ubyte[4096] memory;
    ubyte[16] V;
    ushort I;
    ushort pc;

    ubyte delay_timer;
    ubyte sound_timer;

    bool[64 * 32] pixels;

    /*
        Stack and stack pointer
        used for storing return addresses in subroutine calls
    */
    ushort[24] stack;
    ushort sp;

    bool[16] keys;

    bool running;

    this() {
        pc = 0x200;
        I = 0;
        sp = 0;

        // Load fontset
        for (int i = 0; i < 80; i++) {
            this.memory[i] = chip8_fontset[i];
        }

        funTable = [&this.clr, &this.ret, &this.jpi, &this.call, &this.sei,
            &this.snei, &this.se, &this.ldi, &this.addi, &this.ld,
            &this.or, &this.and, &this.xor, &this.add, &this.sub,
            &this.shr, &this.subn, &this.shl, &this.sne, &this.lda,
            &this.jp, &this.rnd, &this.drw, &this.skp, &this.sknp,
            &this.lddt, &this.ldkp, &this.dtld, &this.ldst, &this.adda,
            &this.ldf, &this.ldb, &this.ldar, &this.ldra];
    }

    void loadRom(string filepath) {
        import std.file;
        import std.stdio;

        assert(exists(filepath), "Error, File not found");

        File f = File(filepath, "r");

        byte[] buffer;
        buffer.length = 4096;

        auto data = f.rawRead(buffer);

        writeln(f.size);

        for (int i = 0; i < f.size; i++) {
            this.memory[0x200 + i] = buffer[i];
        }
        f.close();

        for (ushort i = 0; i < 0xFFFF; i++) {
            cached[i] = this.getInstruction(i);
        }
    }

    ubyte A = 0xA;
    ubyte B = 0xB;
    ubyte C = 0xC;
    ubyte D = 0xD;
    ubyte E = 0xE;
    ubyte F = 0xF;

    void clr(const ushort op) {
        // 00E0 - CLS: Clear the display
        this.pixels = false;
    }

    void ret(const ushort op) {
        // 00EE - RET: Return from a subroutine.
        this.pc = this.stack[--this.sp];
    }

    void jpi(const ushort op) {
        // 1nnn - JP addr: Jump to location nnn
        this.pc = op & 0x0FFF;
    }

    void call(const ushort op) {
        // 2nnn - CALL addr: Call subroutine at nnn
        this.stack[sp++] = this.pc;
        this.pc = op & 0x0FFF;
    }

    void sei(const ushort op) {
        // 3xkk - SE Vx, byte: Skip next instruction if Vx = kk.
        if (V[((op & 0x0F00) >> 8)] == (op & 0x00FF)) {
            this.pc += 2;
        }
    }

    void snei(const ushort op) {
        // 4xkk - SNE Vx, byte: Skip next instruction if Vx != kk
        if (V[((op & 0x0F00) >> 8)] != (op & 0x00FF)) {
            this.pc += 2;
        }
    }

    void se(const ushort op) {
        // 5xy0 - SE Vx, Vy: Skip next instruction if Vx = Vy
        if (V[((op & 0x0F00) >> 8)] == V[((op & 0x00F0) >> 4)]) {
            this.pc += 2;
        }
    }

    void ldi(const ushort op) {
        // 6xkk - LD Vx, byte: Set Vx = kk.
        V[((op & 0x0F00) >> 8)] = cast(ubyte)(op & 0x00FF);
    }

    void addi(const ushort op) {
        // 7xkk - ADD Vx, byte: Set Vx = Vx + kk
        V[((op & 0x0F00) >> 8)] += cast(ubyte)(op & 0x00FF);
    }

    void ld(const ushort op) {
        // 8xy0 - LD Vx, Vy: Set Vx = Vy.
        V[((op & 0x0F00) >> 8)] = V[((op & 0x00F0) >> 4)];
    }

    void or(const ushort op) {
        // 8xy1 - OR Vx, Vy: Set Vx = Vx OR Vy.
        V[((op & 0x0F00) >> 8)] |= V[((op & 0x00F0) >> 4)];
    }

    void and(const ushort op) {
        // 8xy2 - AND Vx, Vy: Set Vx = Vx AND Vy
        V[((op & 0x0F00) >> 8)] &= V[((op & 0x00F0) >> 4)];
    }

    void xor(const ushort op) {
        // 8xy3 - XOR Vx, Vy: Set Vx = Vx XOR Vy.
        V[((op & 0x0F00) >> 8)] ^= V[((op & 0x00F0) >> 4)];
    }

    void add(const ushort op) {
        // 8xy4 - ADD Vx, Vy: Set Vx = Vx + Vy, set VF = carry.
        if (V[((op & 0x0F00) >> 8)] + V[((op & 0x00F0) >> 4)] > 255) {
            V[F] = cast(ubyte)(V[((op & 0x0F00) >> 8)] + V[((op & 0x00F0) >> 4)] - 255);
        }
        V[((op & 0x0F00) >> 8)] += V[((op & 0x00F0) >> 4)];
    }

    void sub(const ushort op) {
        // 8xy5 - SUB Vx, Vy: Set Vx = Vx - Vy, set VF = NOT borrow.
        this.V[F] = V[((op & 0x0F00) >> 8)] > V[((op & 0x00F0) >> 4)] ? 1 : 0;
        V[((op & 0x0F00) >> 8)] -= V[((op & 0x00F0) >> 4)];
    }

    void shr(const ushort op) {
        // 8xy6 - SHR Vx {, Vy}: Set Vx = Vx SHR 1.
        this.V[F] = (V[((op & 0x0F00) >> 8)] & 1) ? 1 : 0;
        V[((op & 0x0F00) >> 8)] >>= 1;
    }

    void subn(const ushort op) {
        // 8xy7 - SUBN Vx, Vy: Set Vx = Vy - Vx,
        this.V[F] = V[((op & 0x00F0) >> 4)] > V[((op & 0x0F00) >> 8)] ? 1 : 0;
        V[((op & 0x0F00) >> 8)] = cast(ubyte)(V[((op & 0x00F0) >> 4)] - V[((op & 0x0F00) >> 8)]);
    }

    void shl(const ushort op) {
        // 8xyE - SHL Vx {, Vy}: Set Vx = Vx SHL 1.
        this.V[F] = (V[((op & 0x0F00) >> 8)] & 0b10000000) >> 7;
        V[((op & 0x0F00) >> 8)] <<= 1;
    }

    void sne(const ushort op) {
        // 9xy0 - SNE Vx, Vy: Skip next instruction if Vx != Vy
        if (V[((op & 0x0F00) >> 8)] != V[((op & 0x00F0) >> 4)]) {
            this.pc += 2;
        }
    }

    void lda(const ushort op) {
        // Annn - LD I, addr: Set I = nnn.
        I = op & 0x0FFF;
    }

    void jp(const ushort op) {
        // Bnnn - JP V0, addr: Jump to location nnn + V0.
        this.pc = cast(ushort)(V[0] + op & 0x0FFF);
    }

    void rnd(const ushort op) {
        // Cxkk - RND Vx, byte: Set Vx = random byte AND kk.
        V[((op & 0x0F00) >> 8)] = cast(ubyte)(uniform(0, 256) & op & 0x00FF);
    }

    void drw(const ushort op) {
        // Dxyn - DRW Vx, Vy, nibble: Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision
        this.V[F] = this.Dxyn(V[((op & 0x0F00) >> 8)], V[((op & 0x00F0) >> 4)], (op & 0x000F)) ? 1
            : 0;
    }

    void skp(const ushort op) {
        // Ex9E - SKP Vx: Skip next instruction if key with the value of Vx is pressed.
        if (this.keys[V[((op & 0x0F00) >> 8)]]) {
            this.pc += 2;
        }
    }

    void sknp(const ushort op) {
        // ExA1 - SKNP Vx: Skip next instruction if key with the value of Vx is not pressed
        if (!this.keys[V[((op & 0x0F00) >> 8)]]) {
            this.pc += 2;
        }
    }

    void lddt(const ushort op) {
        // Fx07 - LD Vx, DT: Set Vx = delay timer value.
        V[((op & 0x0F00) >> 8)] = this.delay_timer;
    }

    void ldkp(const ushort op) {
        // Fx0A - LD Vx, K: Wait for a key press, store the value of the key in Vx.
        if (this.getPress() == 255) {
            this.pc -= 2;
            printKeys();
        }
        else {
            V[((op & 0x0F00) >> 8)] = this.getPress();
        }
    }

    void dtld(const ushort op) {
        // Fx15 - LD DT, Vx: Set delay timer = Vx.
        this.delay_timer = V[((op & 0x0F00) >> 8)];
    }

    void ldst(const ushort op) {
        // Fx18 - LD ST, Vx: Set sound timer = Vx.
        this.sound_timer = V[((op & 0x0F00) >> 8)];
    }

    void adda(const ushort op) {
        // Fx1E - ADD I, Vx: Set I = I + Vx.
        I += V[((op & 0x0F00) >> 8)];
    }

    void ldf(const ushort op) {
        // Fx29 - LD F, Vx: Set I = location of sprite for digit Vx.
        I = 5 * V[((op & 0x0F00) >> 8)];
    }

    void ldb(const ushort op) {
        // Fx33 - LD B, Vx: Store BCD representation of Vx in memory locations I, I+1, and I+2.
        this.memory[I+2] = (V[((op & 0x0F00) >> 8)]) % 10;
        this.memory[I+1] = (V[((op & 0x0F00) >> 8)] / 10) % 10;
        this.memory[I] = (V[((op & 0x0F00) >> 8)] / 100) % 10;

    }

    void ldar(const ushort op) {
        // Fx55 - LD [I], Vx: Store registers V0 through Vx in memory starting at location I
        for (int i = 0; i < ((op & 0x0F00) >> 8); i++) {
            this.memory[I++] = V[i];
        }
    }

    void ldra(const ushort op) {
        // Fx65 - LD Vx, [I]: Read registers V0 through Vx from memory starting at location I.
        for (int i = 0; i < ((op & 0x0F00) >> 8); i++) {
            V[i] = this.memory[I++];
        }
    }

    int getInstruction(const ushort op) {
        if (this.matches(op, 0, 0, E, 0)) { // 00E0 - CLS: Clear the display
            return 0;
        }
        else if (this.matches(op, 0, 0, E, E)) { // 00EE - RET: Return from a subroutine.
            return 1;
        }
        else if (this.matches(op, 1, x, x, x)) { // 1nnn - JP addr: Jump to location nnn
            return 2;
        }
        else if (this.matches(op, 2, x, x, x)) { // 2nnn - CALL addr: Call subroutine at nnn
            return 3;
        }
        else if (this.matches(op, 3, x, x, x)) { // 3xkk - SE Vx, byte: Skip next instruction if Vx = kk.
            return 4;
        }
        else if (this.matches(op, 4, x, x, x)) { // 4xkk - SNE Vx, byte: Skip next instruction if Vx != kk
            return 5;
        }
        else if (this.matches(op, 5, x, x, 0)) { // 5xy0 - SE Vx, Vy: Skip next instruction if Vx = Vy
            return 6;
        }
        else if (this.matches(op, 6, x, x, x)) { // 6xkk - LD Vx, byte: Set Vx = kk.
            return 7;
        }
        else if (this.matches(op, 7, x, x, x)) { // 7xkk - ADD Vx, byte: Set Vx = Vx + kk
            return 8;
        }
        else if (this.matches(op, 8, x, x, 0)) { // 8xy0 - LD Vx, Vy: Set Vx = Vy.
            return 9;
        }
        else if (this.matches(op, 8, x, x, 1)) { // 8xy1 - OR Vx, Vy: Set Vx = Vx OR Vy.
            return 10;
        }
        else if (this.matches(op, 8, x, x, 2)) { // 8xy2 - AND Vx, Vy: Set Vx = Vx AND Vy
            return 11;
        }
        else if (this.matches(op, 8, x, x, 3)) { // 8xy3 - XOR Vx, Vy: Set Vx = Vx XOR Vy.
            return 12;
        }
        else if (this.matches(op, 8, x, x, 4)) { // 8xy4 - ADD Vx, Vy: Set Vx = Vx + Vy, set VF = carry.
            return 13;
        }
        else if (this.matches(op, 8, x, x, 5)) { // 8xy5 - SUB Vx, Vy: Set Vx = Vx - Vy, set VF = NOT borrow.
            return 14;
        }
        else if (this.matches(op, 8, x, x, 6)) { // 8xy6 - SHR Vx {, Vy}: Set Vx = Vx SHR 1.
            return 15;
        }
        else if (this.matches(op, 8, x, x, 7)) { // 8xy7 - SUBN Vx, Vy: Set Vx = Vy - Vx,
            return 16;
        }
        else if (this.matches(op, 8, x, x, E)) { // 8xyE - SHL Vx {, Vy}: Set Vx = Vx SHL 1.
            return 17;
        }
        else if (this.matches(op, 9, x, x, 0)) { // 9xy0 - SNE Vx, Vy: Skip next instruction if Vx != Vy
            return 18;
        }
        else if (this.matches(op, A, x, x, x)) { // Annn - LD I, addr: Set I = nnn.
            return 19;
        }
        else if (this.matches(op, B, x, x, x)) { // Bnnn - JP V0, addr: Jump to location nnn + V0.
            return 20;
        }
        else if (this.matches(op, C, x, x, x)) { // Cxkk - RND Vx, byte: Set Vx = random byte AND kk.
            return 21;
        }
        else if (this.matches(op, D, x, x, x)) { // Dxyn - DRW Vx, Vy, nibble: Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision
            return 22;
        }
        else if (this.matches(op, E, x, 9, E)) { // Ex9E - SKP Vx: Skip next instruction if key with the value of Vx is pressed.
            return 23;
        }
        else if (this.matches(op, E, x, A, 1)) { // ExA1 - SKNP Vx: Skip next instruction if key with the value of Vx is not pressed
            return 24;
        }
        else if (this.matches(op, F, x, 0, 7)) { // Fx07 - LD Vx, DT: Set Vx = delay timer value.
            return 25;
        }
        else if (this.matches(op, F, x, 0, A)) { // Fx0A - LD Vx, K: Wait for a key press, store the value of the key in Vx.
            return 26;
        }
        else if (this.matches(op, F, x, 1, 5)) { // Fx15 - LD DT, Vx: Set delay timer = Vx.
            return 27;
        }
        else if (this.matches(op, F, x, 1, 8)) { // Fx18 - LD ST, Vx: Set sound timer = Vx.
            return 28;
        }
        else if (this.matches(op, F, x, 1, E)) { // Fx1E - ADD I, Vx: Set I = I + Vx.
            return 29;
        }
        else if (this.matches(op, F, x, 2, 9)) { // Fx29 - LD F, Vx: Set I = location of sprite for digit Vx.
            return 30;
        }
        else if (this.matches(op, F, x, 3, 3)) { // Fx33 - LD B, Vx: Store BCD representation of Vx in memory locations I, I+1, and I+2.
            return 31;
        }
        else if (this.matches(op, F, x, 5, 5)) { // Fx55 - LD [I], Vx: Store registers V0 through Vx in memory starting at location I
            return 32;
        }
        else if (this.matches(op, F, x, 6, 5)) { // Fx65 - LD Vx, [I]: Read registers V0 through Vx from memory starting at location I.
            return 33;
        }

        return -1;
    }

    void delegate(const ushort op)[] funTable;

    void badInstruction(const ushort op) {
        import std.stdio;

        writeln();
        writef("Undefined operation for opcode: 0x%X\n", op);
        writef("This was reached at location 0x%X in memory\n", this.pc);
        writeln();
        writeln();

        printMemory(pc - 16, pc + 15);
        assert(0);

    }

    void printMemory(int start, int end) {
        import std.stdio;

        for (int i = start; i < end; i++) {
            if (i % 8 == 0) {
                writeln();
            }
            writef("0x%X ", this.memory[i]);

        }
    }

    void printKeys() {
        import std.stdio;

        for (int i = 0; i < 16; i++) {
            if (i % 4 == 0) {
                writeln();
            }
            writef("%b ", this.keys[i]);
        }
        writeln();
    }

    void printRegisters() {
        import std.stdio;

        for (int i = 0; i < 16; i++) {
            if (i % 8 == 0) {
                writeln();
            }
            writef("%X:%d ", i, V[i]);
        }
        writef("\npc: %x, dt: %d, st: %d, I: %X\n\n", pc, delay_timer, sound_timer, I);
    }

    ubyte getPress() {
        for (ubyte i = 0; i < 16; i++) {
            if (this.keys[i]) {
                return i;
            }
        }
        return 255;
    }

    ubyte x = 255; // x is a placeholder, it is used when it can match any value, 255 is chosen as it is out of range, b1-b4 are really just 4bit numbers
    bool matches(ushort op, ubyte b1, ubyte b2, ubyte b3, ubyte b4) {
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

    int[ushort] cached;
    void cycle() {
        import std.stdio;

        ushort op = (this.memory[pc++] << 8);
        op |= this.memory[pc++];
        writef("opcode: 0x%X", op);
        funTable[cached[op]](op);
        printRegisters();
        writeln();
    }

    bool drawPixel(int x, int y, bool on) {
        this.pixels[(x) % 64 + (y) * 64] ^= on;
        return on && !this.pixels[(x) % 64 + (y) * 64];
    }

    bool Dxyn(ubyte x, ubyte y, ubyte height) {
        ubyte[] sprite = new ubyte[height];
        for (int l = 0; l < height; l++) {
            sprite[l] = this.memory[l + I];
        }
        bool isFlipped = false;
        for (int i = 0; i < height; i++) {
            for (int j = 0; j < 8; j++) {
                if (drawPixel((x + j) % 64, y + i, (sprite[i] >> (7 - j)) & 1)) {
                    isFlipped = true;
                }
            }
        }
        return isFlipped;
    }

}
