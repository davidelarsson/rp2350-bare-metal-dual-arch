# RP2350 Bare-Metal RISC-V LED Blink
# Makefile for building the project

# Program name
TARGET = rp2350_led

# Build directory
BUILD_DIR = build

# Toolchain
AS = riscv32-unknown-elf-as
LD = riscv32-unknown-elf-ld
OBJCOPY = riscv32-unknown-elf-objcopy
ARM_AS = arm-none-eabi-as
ARM_LD = arm-none-eabi-ld
ARM_OBJCOPY = arm-none-eabi-objcopy

# Flags
AS_FLAGS = -march=rv32imac_zicsr -mabi=ilp32
LD_FLAGS = -m elf32lriscv
LD_SCRIPT = rp2350.ld
ARM_AS_FLAGS = -mcpu=cortex-m33 -mthumb

# Source files
SRC = $(TARGET).s
ARM_SRC = core1_arm.s

# Output files in build directory
OBJ = $(BUILD_DIR)/$(TARGET).o
ELF = $(BUILD_DIR)/$(TARGET).elf
BIN = $(BUILD_DIR)/$(TARGET).bin
UF2 = $(BUILD_DIR)/$(TARGET).uf2
ARM_OBJ = $(BUILD_DIR)/core1_arm.o
ARM_ELF = $(BUILD_DIR)/core1_arm.elf
ARM_BIN = $(BUILD_DIR)/core1_arm.bin

.PHONY: all clean upload

all: $(UF2)

# Create build directory if it doesn't exist
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Build ARM binary first (needed for .incbin)
$(ARM_BIN): $(ARM_SRC) | $(BUILD_DIR)
	$(ARM_AS) $(ARM_AS_FLAGS) $(ARM_SRC) -o $(ARM_OBJ)
	$(ARM_LD) -m armelf -Ttext=0 $(ARM_OBJ) -o $(ARM_ELF)
	$(ARM_OBJCOPY) -O binary $(ARM_ELF) $(ARM_BIN)

# Build RISC-V object (depends on ARM binary for .incbin)
$(OBJ): $(SRC) $(LD_SCRIPT) $(ARM_BIN) | $(BUILD_DIR)
	$(AS) $(AS_FLAGS) $(SRC) -o $(OBJ)

$(ELF): $(OBJ)
	$(LD) $(LD_FLAGS) -T $(LD_SCRIPT) $(OBJ) -o $(ELF)

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $(ELF) $(BIN)

$(UF2): $(BIN)
	python3 bin2uf2.py $(BIN) $(UF2)

clean:
	rm -rf $(BUILD_DIR)

# Upload target (requires device in BOOTSEL mode)
upload: $(UF2)
	@if [ -d /Volumes/RP2350 ]; then \
		cp $(UF2) /Volumes/RP2350/; \
		echo "Uploaded $(UF2) to RP2350"; \
	else \
		echo "Error: RP2350 not found. Put device in BOOTSEL mode."; \
		exit 1; \
	fi

