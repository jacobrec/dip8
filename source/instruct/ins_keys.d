module instruct.ins_keys;
import cpu;

unittest {
    // test key press functions
    Chip8 chip = new Chip8();
    // skp(chip);
    // sknp(chip);
    // ldkp(chip);
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
