module cpu;
import instruct.instructions;


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

    ushort op;

    /*
        Stack and stack pointer
        used for storing return addresses in subroutine calls
    */
    ushort[24] stack;
    ushort sp;

    bool[16] keys;

    bool running;
    immutable instruction[ushort] funTable;

    this() {
        // programs start here
        pc = 0x200;

        for (int i = 0; i < 80; i++) {
            this.memory[i] = chip8_fontset[i];
        }

        funTable = getInstructionMap();
    }

    void loadRom(string filepath) {
        import std.file;
        import std.stdio;

        assert(exists(filepath), "Error, File not found");

        File f = File(filepath, "r");

        byte[] buffer;
        buffer.length = 4096;

        f.rawRead(buffer);

        for (int i = 0; i < f.size; i++) {
            this.memory[0x200 + i] = buffer[i];
        }
        f.close();
    }


    void cycle540hz() {
        op = (this.memory[pc++] << 8);
        op |= this.memory[pc++];
        funTable[op](this);
    }

    void cycle60hz() {
        if (this.sound_timer > 0) {
            this.sound_timer--;
        }
        if (this.delay_timer > 0) {
            this.delay_timer--;
        }
    }



    ubyte getPress() {
        for (ubyte i = 0; i < 16; i++) {
            if (this.keys[i]) {
                return i;
            }
        }
        return 255;
    }



    bool drawSprite(ubyte x, ubyte y, ubyte height) {
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

    bool drawPixel(int x, int y, bool on) {
        int ind = (x % 64 + y * 64) % (32 * 64);
        this.pixels[ind] ^= on;
        return on && !this.pixels[ind];
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

}
