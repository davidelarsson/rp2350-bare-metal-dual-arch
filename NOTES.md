# Raspberry Pi Pico 2W
Some experiments.


# TODO

 * Go through everything and clean it up

# Overview
The goal is to run two cores with different architectures simultaneously. This is achieved in examples 8 and 9.
In order to get there, I went through several steps:

 * `1. Blink LED and print to serial terminal`
  - Simple LED blinking and terminal output using the SDK and C
  - This is the only example using the SDK; all others use bare metal assembly coding

 * `2. Bare metal ARM`
  - Blink an LED using bare-metal coding running ARM assembly
  - Includes Makefile for SRAM-only load

 * `3. Bare metal RISC-V`
  - Blink an LED using bare-metal coding running RISC-V assembly

 * `4. Dual-core ARM`
  - Running ARM assembly code on both cores using bare-metal coding

 * `5. Dual-core RISC-V`
  - Running RISC-V assembly code on both cores using bare-metal coding

 * `6. Dual-core multi-image ARM`
  - Useless but interesting example on how `IMAGE_DEF`s work with ARM

 * `7. Dual-core multi-image RISC-V`
  - Useless but interesting example on how `IMAGE_DEF`s work with RISC-V

 * `8. Dual-architecture, ARM boot on core 0, RISC-V on core 1`
  - First example of actually running both ARM and RISC-V code simultaneously
  - ARM boots on core 0, RISC-V runs on core 1

 * `9. Dual-architecture, RISC-V boot on core 0, ARM on core 1`
  - First example of actually running both ARM and RISC-V code simultaneously
  - RISC-V boots on core 0, ARM runs on core 1


# 1. Blink LED and print to serial terminal
Simple getting started program.



# On mac; install GCC for both ARM and RISC-V
`brew install --cask gcc-arm-embedded`
`brew install riscv64-elf-gcc`

There is a slight inconvenience on Mac. The SDK looks for `riscv32-unknown-elf-*`,
but `brew` installs `riscv64-unknown-elf-*`. The binaries are fine, they can
generate 32-bit code, but we have to create a few symlinks:
```bash
cd /opt/homebrew/bin
for tool in riscv64-unknown-elf-*; do
    link_name="${tool/riscv64/riscv32}"
    ln -sf "$tool" "$link_name"
done
echo "Created riscv32 symlinks:"
ls -l riscv32-unknown-elf-gcc riscv32-unknown-elf-g++ riscv32-unknown-elf-ld
```

Now, build the first project:
```bash
cd "1. Blink LED and print to serial terminal"
mkdir build
cd build
cmake .. -DPICO_BOARD=pico2_w -DPICO_SDK_FETCH_FROM_GIT=ON
make
```
CMake options:

`DPICO_BOARD=pico2_w` defines the board used and
`-DPICO_SDK_FETCH_FROM_GIT=ON` tells cmake to fetch the SDK from GitHub.

Copy the `blink.uf2` file to the controller to verify that everything works.

You can run the first example again, but this time add:
`-DPICO_PLATFORM=rp2350-riscv`
To the CMake command. This will build the example using the RISC-V cores instead.


# 2. Bare metal ARM
`2. Bare metal ARM` blinks an LED on GPIO15 using bare metal code.

Two versions are included, one for Flash, the other for SRAM that disappears after a power cycle.


# 3. Bare metal RISC-V
`3. Bare metal RISC-V` works the same as 2, but using the RISC-V CPU instead.



