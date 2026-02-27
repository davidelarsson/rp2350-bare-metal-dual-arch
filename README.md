# rp2350-bare-metal-dual-arch
Bare-metal examples running ARM and RISC-V simultaneously on the RP2350.

The SDK only supports one architecture at a time. This project demonstrates how to run one architecture per core simultaneously.

In order to get there, multiple intermediate steps were taken. The final goal was achieved in examples 8 and 9.

Check out [NOTES.md](Notes.md) for details.


# rp2350-bare-metal-dual-arch
Bare-metal examples running ARM and RISC-V simultaneously on the RP2350.

The Pico SDK only supports one architecture at a time. This project demonstrates how to run different architectures on each core simultaneously - ARM on one core, RISC-V on the other.


# Requirements
A Raspberry Pi Pico 2 (RP2350). It has a built-in LED on the breakout board. This LED is used for all experiments.

Note that the WiFi/Bluetooth-capable Pico 2 W does not have its LED wired to a RP2350 GPIO pin, but instead to its CYW43439 WiFi/Bluetooth chip. So in order to use the LED one has to first initialize the WiFi/Bluetooth chip, then ask it do update the LED each time. This initialization process is quite complex, so I didn't bother with this. So in order to use the Pico 2 W, an external LED connected to one of the RP2350 GPIO pins is recommended. This has been tested. The code changes that are required for this are not included in this repo, however.


# TODO

 * Do bare-metal UART

 * Test the programmable I/O logic


# Overview
In order to reach the goal, multiple intermediate steps were taken:

 * `1. Blink LED and print to serial terminal`
  - Simple LED blinking and UART output using the SDK and C
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

 * `6. Multi-image ARM`
  - Useless but interesting example on how `IMAGE_DEF`s work with ARM

 * `7. Multi-image RISC-V`
  - Useless but interesting example on how `IMAGE_DEF`s work with RISC-V

 * `8. Dual-architecture, ARM boot on core 0, RISC-V on core 1`
  - First example of actually running both ARM and RISC-V code simultaneously
  - ARM boots on core 0, RISC-V runs on core 1

 * `9. Dual-architecture, RISC-V boot on core 0, ARM on core 1`
  - First example of actually running both ARM and RISC-V code simultaneously
  - RISC-V boots on core 0, ARM runs on core 1


# 1. Blink LED and print to serial terminal
Simple getting started program. Both ARM and RISC-V are supported.


## Instructions on MacOS
`brew install --cask gcc-arm-embedded`
`brew install riscv64-elf-gcc`

There is a slight inconvenience on Mac. The SDK looks for `riscv32-unknown-elf-*`,
but `brew` installs `riscv64-unknown-elf-*`. The binaries are fine, they can
generate 32-bit code, but we have to create a few symlinks for the SDK to find them:
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
cmake .. -DPICO_BOARD=pico2 -DPICO_SDK_FETCH_FROM_GIT=ON
make
```
CMake options explanations:

`DPICO_BOARD=pico2_w` defines the board used and
`-DPICO_SDK_FETCH_FROM_GIT=ON` tells cmake to fetch the SDK from GitHub.

Copy the `blink.uf2` file to the controller to verify that everything works.

### RISC-V
Configure and compile the first example again, but this time add:
`-DPICO_PLATFORM=rp2350-riscv`
To the CMake command. This will build the example using the RISC-V cores instead.

```bash
cd "1. Blink LED and print to serial terminal"
mkdir build
cd build
cmake .. -DPICO_PLATFORM=rp2350-riscv -DPICO_BOARD=pico2 -DPICO_SDK_FETCH_FROM_GIT=ON
make
```
Again, copy `blink.uf2` to the RP2350 and it will do the exact same thing as before,
only running on a RISC-V core.


# 2. Bare metal ARM
Blink an LED, but using bare-metal coding without the SDK.

On my mac, all I need to do is:
```bash
make
make upload
```
The last command copies the `blink.uf2` to `/Volumes/RP2350`, which resets the
controller and boots the program. It blinks with a frequency of about 0.5 Hz.

An image to be recognized as valid by the RP2350 must start with an `IMAGE_DEF`
definition. ARM also requires a so-called `vector table` which must be following
immediatedly after the `IMAGE_DEF`. One can also include an `VECTOR_TABLE` item
in the image definition to point out where the vector table is found. An example
of this can be found in `6. Multi-image ARM`. The vector table defines
things like entry point, initial stack pointer value and other things.

## RAM version
A separate version of the source, called `rp2350_led_ram.s` that blinks the LED with a
much higher frequency, 2-3 Hz or so. This is to make it clear which version of the
blinking program that is currently running.

```bash
make -f Makefile.ram
make -f Makefile.ram  upload
```
This does not upload the code to Flash, but only to SRAM. So it will only stay in
memory until the device is power-cycled.

Thus, when you power-cycle the device, it goes back to blink with the slower
frequency again.


# 3. Bare metal RISC-V
Blink an LED, just like example 2, but using bare-metal RISC-V assembly.

```bash
make
make upload
```

RISC-V does not use `vector table`s like ARM. As such, the entry point for the
image must be provided by other means. For the RP2350, it is done by including
an `ENTRY_POINT` item in the image definition. `ENTRY_POINT` also defines the
initial value of the stack pointer.

If there is a `VECTOR_TABLE` item in the image definition for a RISC-V, image
definition, it will be ignored (see `5.9.3.3. VECTOR_TABLE item`).


# 4. Dual-core ARM
Boot the second core, but stick to ARM for both cores.

Core 1 boots into a `wait_for_vector` function that sleep-waits for relevant data
to be sent from core 0 over the FIFO. When core 1 receives the correct sequence of data,
t will jump to the entry address sent by Core 0. The source of the `wait_for_vector`
function is documented in `https://github.com/raspberrypi/pico-bootrom-rp2350`.

Note that there are two different `wait_for_vector` functions for ARM and RISC-V, but
they work exactly the same.

So in this example, core 0 configures the I/O pin and core 1 does the actual blinking.

Core 0 sets the LED high, and waits a second or so, then launches core 1.
Core 1 starts the blinking.


# 5. Dual-core RISC-V
Same as example 4, but running both cores of the RISC-V CPU instead.

This example includes more details on how the second core is actually booted.

This contains the first instance of the hilarious Hazard3 hack:
In order to wake the other core up, you need to execute an `h3.unblock` instruction.
This is mapped to a seemingly random RISC-V opcode that would otherwise be a NOP:
`slt x0, x0, x1`
Since x0 is always zero, and any writes to it are ignored, this is always a NOP.
However, the RP2350 bootrom treats this instruction as a special signal to unblock
the other core.


# 6. Multi-image ARM
Experiment with setting up multiple `IMAGE_DEF`s.

Not used in the end, but can serve as an interesting demonstration nevertheless.

I wrote this because I mistakenly thought I had to upload two different images, one
for ARM, the other for RISC-V and then boot one image per core. This is now how it
works however, but I leave it here anyway.

The first image just turns on the LED and lets it stay on. The second image
blinks the LED. It is always the last image in the loop that is booted by bootrom.

(There seems to be no way to tell the bootrom to boot another image in a block loop
without creating a custom bootloader in the last image. In order to boot other
images, you must use a higher-level abstraction in the form of partitions. We have
not experimented with that.)

Examples of `VECTOR_TABLE` items in the image definitions are included. Again,
the second image is booted, which uses the second vector table. In order to start
the code that the first vector table refers to, update the pointer to the vector
table of the second image:
```
    .word vector_table_second  // Address of second vector table
```
so that it points to `vector_table_first` instead.



# 7. Multi-image RISC-V
Same as example 6, but running RISC-V instead.

Note that the image definitions don't include `VECTOR_TABLE` items (since that is
only used by ARM), but instead use `ENTRY_POINT` items.

Detailed descriptions of `IMAGE_DEF` items can be found in the source for this
example.


# 8. ARM on core 0, RISC-V on core 1
First example of actually running both ARM and RISC-V code simultaneously

ARM boots on core 0, RISC-V runs on core 1.

First we assemble the RISC-V code. Then the ARM source code includes the
generated binary using the `incbin` directive.

`ARCHSEL` determines what architecture each core should use and is sampled on
reset, so we update the register to RISC-V for core 1, then reset core 1.

This will boot core 1 into its RISC-V version of `wait_for_vector_table`.
Thus we can launch core 1 as usual, and point it to the included RISC-V
binary.

Just like in examples 4 and 5, core 0 sets up the pin and core 1 does
the blinking.


# 9. RISC-V on core 0, ARM on core 1
Similar to example 8, but reversed: RISC-V boots on core 0, ARM runs on core 1.

Thus `ARCHSEL` is set to ARM for core 1 before core 1 is reset.





