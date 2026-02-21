# Raspberry Pi Pico 2W
Some experiments.

# TODO

 * Understand the boot process

 * Put a blink program in boot2?


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


