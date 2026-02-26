# RP2350 Bare-Metal ARM LED Blink
# Makefile for building the project

# Program name
TARGET = rp2350_led

# Build directory
BUILD_DIR = build

# Toolchain
AS = arm-none-eabi-as
LD = arm-none-eabi-ld
OBJCOPY = arm-none-eabi-objcopy
RISCV_AS = riscv64-unknown-elf-as
RISCV_LD = riscv64-unknown-elf-ld
RISCV_OBJCOPY = riscv64-unknown-elf-objcopy

# Flags
AS_FLAGS = -mcpu=cortex-m33 -mthumb
LD_FLAGS = 
LD_SCRIPT = rp2350.ld
RISCV_AS_FLAGS = -march=rv32imac -mabi=ilp32

# Source files
SRC = $(TARGET).s
RISCV_SRC = core1_riscv.s

# Output files in build directory
OBJ = $(BUILD_DIR)/$(TARGET).o
ELF = $(BUILD_DIR)/$(TARGET).elf
BIN = $(BUILD_DIR)/$(TARGET).bin
UF2 = $(BUILD_DIR)/$(TARGET).uf2
RISCV_OBJ = $(BUILD_DIR)/core1_riscv.o
RISCV_ELF = $(BUILD_DIR)/core1_riscv.elf
RISCV_BIN = $(BUILD_DIR)/core1_riscv.bin

.PHONY: all clean upload

all: $(UF2)

# Create build directory if it doesn't exist
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Build RISC-V binary first
$(RISCV_BIN): $(RISCV_SRC) | $(BUILD_DIR)
	$(RISCV_AS) $(RISCV_AS_FLAGS) $(RISCV_SRC) -o $(RISCV_OBJ)
	$(RISCV_LD) -m elf32lriscv -Ttext=0 $(RISCV_OBJ) -o $(RISCV_ELF)
	$(RISCV_OBJCOPY) -O binary $(RISCV_ELF) $(RISCV_BIN)

$(OBJ): $(SRC) $(LD_SCRIPT) $(RISCV_BIN) | $(BUILD_DIR)
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

