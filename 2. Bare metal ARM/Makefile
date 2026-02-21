# RP2350 Bare-Metal LED Blink
# Makefile for building the project

# Program name
TARGET = rp2350_led

# Build directory
BUILD_DIR = build

# Toolchain
AS = arm-none-eabi-as
LD = arm-none-eabi-ld
OBJCOPY = arm-none-eabi-objcopy

# Flags
AS_FLAGS = -mcpu=cortex-m33 -mthumb
LD_FLAGS = -nostdlib
LD_SCRIPT = rp2350.ld

# Source files
SRC = $(TARGET).s

# Output files in build directory
OBJ = $(BUILD_DIR)/$(TARGET).o
ELF = $(BUILD_DIR)/$(TARGET).elf
BIN = $(BUILD_DIR)/$(TARGET).bin
UF2 = $(BUILD_DIR)/$(TARGET).uf2

.PHONY: all clean

all: $(UF2)

# Create build directory if it doesn't exist
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OBJ): $(SRC) $(LD_SCRIPT) | $(BUILD_DIR)
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
