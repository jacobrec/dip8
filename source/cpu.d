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
    }

    ubyte A = 0xA;
    ubyte B = 0xB;
    ubyte C = 0xC;
    ubyte D = 0xD;
    ubyte E = 0xE;
    ubyte F = 0xF;

    void doInstruction(const ushort op) {
        immutable ubyte a = (op & 0xF000) >> 12;
        immutable ubyte b = (op & 0x0F00) >> 8;
        immutable ubyte c = (op & 0x00F0) >> 4;
        immutable ubyte d = (op & 0x000F);

        if (this.matches(op, 0, 0, E, 0)) { // 00E0 - CLS: Clear the display
            this.pixels = false;
        }
        else if (this.matches(op, 0, 0, E, E)) { // 00EE - RET: Return from a subroutine.
            this.pc = this.stack[--this.sp];
        }
        else if (this.matches(op, 1, x, x, x)) { // 1nnn - JP addr: Jump to location nnn
            this.pc = op & 0x0FFF;
        }
        else if (this.matches(op, 2, x, x, x)) { // 2nnn - CALL addr: Call subroutine at nnn
            this.stack[sp++] = this.pc;
            this.pc = op & 0x0FFF;
        }
        else if (this.matches(op, 3, x, x, x)) { // 3xkk - SE Vx, byte: Skip next instruction if Vx = kk.
            if (V[b] == (op & 0x00FF)) {
                this.pc += 2;
            }
        }
        else if (this.matches(op, 4, x, x, x)) { // 4xkk - SNE Vx, byte: Skip next instruction if Vx != kk
            if (V[b] != (op & 0x00FF)) {
                this.pc += 2;
            }
        }
        else if (this.matches(op, 5, x, x, 0)) { // 5xy0 - SE Vx, Vy: Skip next instruction if Vx = Vy
            if (V[b] == V[c]) {
                this.pc += 2;
            }
        }
        else if (this.matches(op, 6, x, x, x)) { // 6xkk - LD Vx, byte: Set Vx = kk.
            V[b] = cast(ubyte) op & 0x00FF;
        }
        else if (this.matches(op, 7, x, x, x)) { // 7xkk - ADD Vx, byte: Set Vx = Vx + kk
            V[b] += cast(ubyte) op & 0x00FF;
        }
        else if (this.matches(op, 8, x, x, 0)) { // 8xy0 - LD Vx, Vy: Set Vx = Vy.
            V[b] = V[c];
        }
        else if (this.matches(op, 8, x, x, 1)) { // 8xy1 - OR Vx, Vy: Set Vx = Vx OR Vy.
            V[b] |= V[c];
        }
        else if (this.matches(op, 8, x, x, 2)) { // 8xy2 - AND Vx, Vy: Set Vx = Vx AND Vy
            V[b] &= V[c];
        }
        else if (this.matches(op, 8, x, x, 3)) { // 8xy3 - XOR Vx, Vy: Set Vx = Vx XOR Vy.
            V[b] ^= V[c];
        }
        else if (this.matches(op, 8, x, x, 4)) { // 8xy4 - ADD Vx, Vy: Set Vx = Vx + Vy, set VF = carry.
            if (V[b] + V[c] > 255) {
                V[F] = cast(ubyte)(V[b] + V[c] - 255);
            }
            V[b] += V[c];
        }
        else if (this.matches(op, 8, x, x, 5)) { // 8xy5 - SUB Vx, Vy: Set Vx = Vx - Vy, set VF = NOT borrow.
            this.V[F] = V[b] > V[c] ? 1 : 0;
            V[b] -= V[c];
        }
        else if (this.matches(op, 8, x, x, 6)) { // 8xy6 - SHR Vx {, Vy}: Set Vx = Vx SHR 1.
            this.V[F] = V[b] & 1 ? 1 : 0;
            V[b] >>= 1;
        }
        else if (this.matches(op, 8, x, x, 7)) { // 8xy7 - SUBN Vx, Vy: Set Vx = Vy - Vx,
            this.V[F] = V[c] > V[b] ? 1 : 0;
            V[b] = cast(ubyte)(V[c] - V[b]);
        }
        else if (this.matches(op, 8, x, x, E)) { // 8xyE - SHL Vx {, Vy}: Set Vx = Vx SHL 1.
            this.V[F] = V[b] & 0b10000000 >> 7;
            V[b] <<= 1;
        }
        else if (this.matches(op, 9, x, x, 0)) { // 9xy0 - SNE Vx, Vy: Skip next instruction if Vx != Vy
            if (V[b] != V[c]) {
                this.pc += 2;
            }
        }
        else if (this.matches(op, A, x, x, x)) { // Annn - LD I, addr: Set I = nnn.
            I = op & 0x0FFF;
        }
        else if (this.matches(op, B, x, x, x)) { // Bnnn - JP V0, addr: Jump to location nnn + V0.
            this.pc = cast(ushort)(V[0] + op & 0x0FFF);
        }
        else if (this.matches(op, C, x, x, x)) { // Cxkk - RND Vx, byte: Set Vx = random byte AND kk.
            import std.random;

            V[b] = cast(ubyte)(uniform(0, 256) & op & 0x00FF);
        }
        else if (this.matches(op, D, x, x, x)) { // Dxyn - DRW Vx, Vy, nibble: Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision
            this.V[F] = this.Dxyn(V[b], V[c], d) ? 1 : 0;
        }
        else if (this.matches(op, E, x, 9, E)) { // Ex9E - SKP Vx: Skip next instruction if key with the value of Vx is pressed.
            if (this.keys[V[b]]) {
                this.pc += 2;
            }
        }
        else if (this.matches(op, E, x, A, 1)) { // ExA1 - SKNP Vx: Skip next instruction if key with the value of Vx is not pressed
            if (!this.keys[V[b]]) {
                this.pc += 2;
            }
        }
        else if (this.matches(op, F, x, 0, 7)) { // Fx07 - LD Vx, DT: Set Vx = delay timer value.
            V[b] = this.delay_timer;
        }
        else if (this.matches(op, F, x, 0, A)) { // Fx0A - LD Vx, K: Wait for a key press, store the value of the key in Vx.
            if (this.getPress() == 255) {
                this.pc -= 2;
                printKeys();
            }
            else {
                V[b] = this.getPress();
            }
        }
        else if (this.matches(op, F, x, 1, 5)) { // Fx15 - LD DT, Vx: Set delay timer = Vx.
            this.delay_timer = V[b];
        }
        else if (this.matches(op, F, x, 1, 8)) { // Fx18 - LD ST, Vx: Set sound timer = Vx.
            this.sound_timer = V[b];
        }
        else if (this.matches(op, F, x, 1, E)) { // Fx1E - ADD I, Vx: Set I = I + Vx.
            I += V[b];
        }
        else if (this.matches(op, F, x, 2, 9)) { // Fx29 - LD F, Vx: Set I = location of sprite for digit Vx.
            I = 5 * V[b];
        }
        else if (this.matches(op, F, x, 3, 3)) { // Fx33 - LD B, Vx: Store BCD representation of Vx in memory locations I, I+1, and I+2.
            this.memory[I] = V[b] % 10;
            this.memory[I + 1] = (V[b] / 10) % 10;
            this.memory[I + 2] = (V[b] / 100) % 10;
        }
        else if (this.matches(op, F, x, 5, 5)) { // Fx55 - LD [I], Vx: Store registers V0 through Vx in memory starting at location I
            for (int i = 0; i < b; i++) {
                this.memory[I++] = V[i];
            }
        }
        else if (this.matches(op, F, x, 6, 5)) { // Fx65 - LD Vx, [I]: Read registers V0 through Vx from memory starting at location I.
            for (int i = 0; i < b; i++) {
                V[i] = this.memory[i + I];
            }
        }
        else {
            badInstruction(op);
        }
    }

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
            writef("%d ", V[i]);
        }
        writeln();
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

    void cycle() {
        this.doInstruction((this.memory[pc++] << 8) | this.memory[pc++]);
        if (sound_timer > 0) {
            sound_timer--;
        }
        if (delay_timer > 0) {
            delay_timer--;
        }
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
