# RP2350 Bare-Metal LED Blink

A minimal bare-metal assembly program that blinks an LED on GPIO15 for the Raspberry Pi Pico 2W (RP2350).

## Project Structure

```
.
├── rp2350_led.s              # Flash version source
├── rp2350.ld                 # Flash linker script
├── rp2350_led_ram.s          # RAM version source
├── rp2350_ram.ld             # RAM linker script
├── bin2uf2.py                # Binary to UF2 converter
├── Makefile                  # Build for Flash
├── Makefile.ram              # Build for RAM
└── README.md                 # This file
```

## Two Versions

### Flash Version (Persistent)
- Loads to `0x10000000` (flash)
- Survives power cycles
- Build: `make`
- Upload: `make upload`

### RAM Version (Temporary)
- Loads to `0x20000000` (RAM)
- Lost on power cycle
- Faster execution (RAM vs flash)
- Build: `make -f Makefile.ram`
- Upload: `make -f Makefile.ram upload`

## Requirements

- `arm-none-eabi-gcc` toolchain
- Python 3
- Raspberry Pi Pico 2W (RP2350)

## Building

**Flash version:**
```bash
make
```

**RAM version:**
```bash
make -f Makefile.ram
```

This will produce UF2 files in `build/` ready to upload.

## Uploading

1. Hold BOOTSEL button and connect Pico 2W via USB
2. Run:
```bash
make upload              # Flash version
# or
make -f Makefile.ram upload   # RAM version
```

Or manually copy the UF2 file:
```bash
cp build/rp2350_led.uf2 /Volumes/RP2350/      # Flash
cp build/rp2350_led_ram.uf2 /Volumes/RP2350/  # RAM
```

## How It Works

The device knows whether to execute from Flash or RAM based on the **UF2 target addresses**:

- `bin2uf2.py` embeds target addresses in each UF2 block
- Flash: `0x10000000` → bootrom writes to flash, boots from flash
- RAM: `0x20000000` → bootrom writes to RAM, boots from RAM

The linker script organizes the binary, but the UF2 converter tells the bootrom where to load it.

## Cleaning

```bash
make clean
# or
make -f Makefile.ram clean
```

## Features

- Pure bare-metal assembly (no SDK)
- Minimal IMAGE_DEF metadata for RP2350 boot
- Blinks GPIO15 LED with ~1 second interval
- Total size: ~196 bytes

## Documentation

See [RP2350_BARE_METAL_LESSONS.md](RP2350_BARE_METAL_LESSONS.md) for detailed explanation of:
- RP2350 boot mechanism
- Key differences from RP2040
- Register addresses and configurations
- Common pitfalls and solutions

## License

This is example code for educational purposes.
