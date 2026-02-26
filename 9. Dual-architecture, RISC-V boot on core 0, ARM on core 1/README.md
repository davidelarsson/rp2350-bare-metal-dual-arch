# Bare Metal RISC-V LED Blink for RP2350

This is a minimal bare-metal RISC-V assembly program that blinks GPIO15 on the Raspberry Pi Pico 2W (RP2350).

## Files

- `rp2350_led.s` - Main RISC-V assembly source file
- `rp2350.ld` - Linker script
- `bin2uf2.py` - Python script to convert binary to UF2 format
- `Makefile` - Build automation

## Building

Simply run:
```bash
make
```

This will create `build/rp2350_led.uf2` which can be uploaded to the Pico 2W.

## Uploading

1. Hold the BOOTSEL button while plugging in the Pico 2W
2. Copy the UF2 file to the RP2350 drive:
   ```bash
   cp build/rp2350_led.uf2 /Volumes/RP2350/
   ```

## How It Works

The program:
1. Configures the IMAGE_DEF block for RISC-V boot
2. Releases IO_BANK0 and PADS_BANK0 from reset
3. Configures GPIO15 pad settings
4. Sets GPIO15 function to SIO (Software I/O)
5. Enables GPIO15 as output
6. Blinks GPIO15 on/off with ~1 second delays

## Key Learnings

This project required several critical fixes to work:

1. **IMAGE_DEF LAST item size** - Must specify total word count of all items (4 words), not just 1
2. **ENTRY_POINT item** - Required to specify where code starts (bootrom jumps to lowest address by default)
3. **UF2 format** - End magic must come AFTER padding, not before
4. **Register addresses** - RESETS_BASE is 0x40020000, IO_BANK0_BASE is 0x40028000
5. **Reset bits** - IO_BANK0 is bit 6, PADS_BANK0 is bit 9 (not bit 12!)
6. **SIO offsets** - GPIO_OE_SET is 0x38, GPIO_OUT_SET is 0x18, GPIO_OUT_CLR is 0x20
7. **PAD configuration** - Required to configure PADS_BANK0 for the GPIO to function

## Toolchain

Requires the RISC-V GNU toolchain:
- `riscv32-unknown-elf-as` - Assembler
- `riscv32-unknown-elf-ld` - Linker
- `riscv32-unknown-elf-objcopy` - Binary converter

## Clean

To remove build artifacts:
```bash
make clean
```
