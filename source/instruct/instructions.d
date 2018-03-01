module instruct.instructions;

import cpu;

import instruct.ins_arithmatic;
import instruct.ins_drawing;
import instruct.ins_flow;
import instruct.ins_keys;
import instruct.ins_load;
import instruct.ins_logical;
import instruct.ins_timers;


// convenince variables to save a keystroke
immutable ubyte A = 0xA;
immutable ubyte B = 0xB;
immutable ubyte C = 0xC;
immutable ubyte D = 0xD;
immutable ubyte E = 0xE;
immutable ubyte F = 0xF;
immutable ubyte x = 255; // x is a placeholder, it is used when it can match any value, 255 is chosen as it is out of range, b1-b4 are really just 4bit numbers

pure instruction getInstruction(const ushort op) {
    if (matches(op, 0, 0, E, 0)) { // 00E0 - CLS: Clear the display
        return &clr;
    }
    else if (matches(op, 0, 0, E, E)) { // 00EE - RET: Return from a subroutine.
        return &ret;
    }
    else if (matches(op, 1, x, x, x)) { // 1nnn - JPI addr: Jump to location nnn
        return &jpi;
    }
    else if (matches(op, 2, x, x, x)) { // 2nnn - CALL addr: Call subroutine at nnn
        return &call;
    }
    else if (matches(op, 3, x, x, x)) { // 3xkk - SEI Vx, byte: Skip next instruction if Vx = kk.
        return &sei;
    }
    else if (matches(op, 4, x, x, x)) { // 4xkk - SNE Vx, byte: Skip next instruction if Vx != kk
        return &snei;
    }
    else if (matches(op, 5, x, x, 0)) { // 5xy0 - SE Vx, Vy: Skip next instruction if Vx = Vy
        return &se;
    }
    else if (matches(op, 6, x, x, x)) { // 6xkk - LDI Vx, byte: Set Vx = kk.
        return &ldi;
    }
    else if (matches(op, 7, x, x, x)) { // 7xkk - ADD Vx, byte: Set Vx = Vx + kk
        return &addi;
    }
    else if (matches(op, 8, x, x, 0)) { // 8xy0 - LD Vx, Vy: Set Vx = Vy.
        return &ld;
    }
    else if (matches(op, 8, x, x, 1)) { // 8xy1 - OR Vx, Vy: Set Vx = Vx OR Vy.
        return &or;
    }
    else if (matches(op, 8, x, x, 2)) { // 8xy2 - AND Vx, Vy: Set Vx = Vx AND Vy
        return &and;
    }
    else if (matches(op, 8, x, x, 3)) { // 8xy3 - XOR Vx, Vy: Set Vx = Vx XOR Vy.
        return &xor;
    }
    else if (matches(op, 8, x, x, 4)) { // 8xy4 - ADD Vx, Vy: Set Vx = Vx + Vy, set VF = carry.
        return &add;
    }
    else if (matches(op, 8, x, x, 5)) { // 8xy5 - SUB Vx, Vy: Set Vx = Vx - Vy, set VF = NOT borrow.
        return &sub;
    }
    else if (matches(op, 8, x, x, 6)) { // 8xy6 - SHR Vx {, Vy}: Set Vx = Vx SHR 1.
        return &shr;
    }
    else if (matches(op, 8, x, x, 7)) { // 8xy7 - SUBN Vx, Vy: Set Vx = Vy - Vx,
        return &subn;
    }
    else if (matches(op, 8, x, x, E)) { // 8xyE - SHL Vx {, Vy}: Set Vx = Vx SHL 1.
        return &shl;
    }
    else if (matches(op, 9, x, x, 0)) { // 9xy0 - SNE Vx, Vy: Skip next instruction if Vx != Vy
        return &sne;
    }
    else if (matches(op, A, x, x, x)) { // Annn - LD I, addr: Set I = nnn.
        return &lda;
    }
    else if (matches(op, B, x, x, x)) { // Bnnn - JP V0, addr: Jump to location nnn + V0.
        return &jp;
    }
    else if (matches(op, C, x, x, x)) { // Cxkk - RND Vx, byte: Set Vx = random byte AND kk.
        return &rnd;
    }
    else if (matches(op, D, x, x, x)) { // Dxyn - DRW Vx, Vy, nibble: Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision
        return &drw;
    }
    else if (matches(op, E, x, 9, E)) { // Ex9E - SKP Vx: Skip next instruction if key with the value of Vx is pressed.
        return &skp;
    }
    else if (matches(op, E, x, A, 1)) { // ExA1 - SKNP Vx: Skip next instruction if key with the value of Vx is not pressed
        return &sknp;
    }
    else if (matches(op, F, x, 0, 7)) { // Fx07 - LD Vx, DT: Set Vx = delay timer value.
        return &lddt;
    }
    else if (matches(op, F, x, 0, A)) { // Fx0A - LD Vx, K: Wait for a key press, store the value of the key in Vx.
        return &ldkp;
    }
    else if (matches(op, F, x, 1, 5)) { // Fx15 - LD DT, Vx: Set delay timer = Vx.
        return &dtld;
    }
    else if (matches(op, F, x, 1, 8)) { // Fx18 - LD ST, Vx: Set sound timer = Vx.
        return &ldst;
    }
    else if (matches(op, F, x, 1, E)) { // Fx1E - ADD I, Vx: Set I = I + Vx.
        return &adda;
    }
    else if (matches(op, F, x, 2, 9)) { // Fx29 - LD F, Vx: Set I = location of sprite for digit Vx.
        return &ldf;
    }
    else if (matches(op, F, x, 3, 3)) { // Fx33 - LD B, Vx: Store BCD representation of Vx in memory locations I, I+1, and I+2.
        return &ldb;
    }
    else if (matches(op, F, x, 5, 5)) { // Fx55 - LD [I], Vx: Store registers V0 through Vx in memory starting at location I
        return &ldar;
    }
    else if (matches(op, F, x, 6, 5)) { // Fx65 - LD Vx, [I]: Read registers V0 through Vx from memory starting at location I.
        return &ldra;
    }

    return &badop;
}

enum funTableLocs {
    CLR,
    RET,
    JPI,
    CALL,
    SEI,
    SNEI,
    SE,
    LDI,
    ADDI,
    LD,
    OR,
    AND,
    XOR,
    ADD,
    SUB,
    SHR,
    SUBN,
    SHL,
    SNE,
    LDA,
    JP,
    RND,
    DRW,
    SKP,
    SKNP,
    LDDT,
    LDKP,
    DTLD,
    LDST,
    ADDA,
    LDF,
    LDB,
    LDAR,
    LDRA
}

alias instruction = void function(Chip8 chip);
pure instruction[ushort] getInstructionMap() {
    instruction[ushort] cached;
    for (ushort i = 0; i < 0xFFFF; i++) {
        cached[i] = getInstruction(i);
    }
    return cached;
}

void badop(Chip8 chip) {
    import std.stdio;

    writeln("##### ERROR #####");
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
