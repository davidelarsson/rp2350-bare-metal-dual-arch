# RP2350 Bare-Metal LED Blink

A minimal bare-metal assembly program that blinks an LED on GPIO15 for the Raspberry Pi Pico 2W (RP2350).

## Project Structure

```
.
├── rp2350_led.s              # Main assembly source file
├── rp2350.ld                 # Linker script
├── bin2uf2.py                # Binary to UF2 converter
├── Makefile                  # Build script
├── README.md                 # This file
└── RP2350_BARE_METAL_LESSONS.md  # Comprehensive documentation
```

## Requirements

- `arm-none-eabi-gcc` toolchain
- Python 3
- Raspberry Pi Pico 2W (RP2350)

## Building

```bash
make
```

This will produce `rp2350_led.uf2` ready to upload.

## Uploading

1. Hold BOOTSEL button and connect Pico 2W via USB
2. Run:
```bash
make upload
```

Or manually copy the UF2 file:
```bash
cp rp2350_led.uf2 /Volumes/RP2350/
```

## Cleaning

```bash
make clean
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
