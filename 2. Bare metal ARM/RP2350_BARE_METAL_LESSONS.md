# RP2350 Bare-Metal Programming: Lessons Learned

## Summary
Successfully created a bare-metal assembly program to control GPIO15 LED on RP2350 (Pico 2W) after discovering multiple critical differences between RP2040 and RP2350.

## Critical Issues Encountered

### 1. **Boot Mechanism Difference (Most Critical)**
**Problem:** Initially tried to use RP2040's boot2 (second-stage bootloader) approach, which doesn't work on RP2350.

**Solution:** RP2350 uses an **IMAGE_DEF metadata block** instead of boot2:
- Bootrom automatically sets up XIP (Execute In Place) from flash
- Requires IMAGE_DEF block with specific marker bytes in first 4KB of flash
- Minimum viable IMAGE_DEF structure:
  ```assembly
  .word 0xffffded3       // PICOBIN_BLOCK_MARKER_START
  .word 0x10210142       // IMAGE_TYPE: Arm, Secure, EXE, RP2350
  .word 0x000001ff       // LAST item
  .word 0x00000000       // Next block pointer (self-loop)
  .word 0xab123579       // PICOBIN_BLOCK_MARKER_END
  ```

**Reference:** RP2350 Datasheet Section 5.9.5 - IMAGE_DEF metadata

---

### 2. **Memory Map Changes**
**Problem:** RP2350 has different peripheral base addresses than RP2040.

**Wrong Addresses (RP2040):**
- RESETS_BASE: 0x4000f000
- IO_BANK0_BASE: 0x40014000

**Correct Addresses (RP2350):**
- RESETS_BASE: **0x40020000**
- IO_BANK0_BASE: **0x40028000**
- PADS_BANK0_BASE: **0x40038000**
- SIO_BASE: 0xd0000000 (unchanged)

**Reference:** RP2350 Datasheet Section 2.2 - Address Map

---

### 3. **Reset Register Bit Positions**
**Problem:** Incorrectly assumed IO_BANK0 and PADS_BANK0 used same bit positions as RP2040.

**Wrong Bits:**
- IO_BANK0: bit 5
- PADS_BANK0: bit 8

**Correct Bits (RP2350):**
- IO_BANK0: **bit 6**
- PADS_BANK0: **bit 9**

**Reference:** RP2350 Datasheet - RESETS: RESET Register (Offset 0x0)

---

### 4. **Reset Handling Method**
**Problem:** Initially tried using atomic XOR register (RESETS_BASE + 0x3000) to clear reset bits.

**Solution:** Must use **read-modify-write** with BICS instruction:
```assembly
ldr  r3, [r0, #0x0]   // Read RESET register
bics r3, r3, r1       // Clear bits (release from reset)
str  r3, [r0, #0x0]   // Write back
```

**Why:** Direct write to RESET register at offset 0x0 with cleared bits, not atomic operation.

---

### 5. **SIO Register Offsets**
**Problem:** Used incorrect offsets for GPIO output enable and output value registers.

**Wrong Offsets:**
- GPIO_OE_SET: 0x024
- GPIO_OUT_SET: 0x014

**Correct Offsets (RP2350):**
- GPIO_OE_SET: **0x038**
- GPIO_OUT_SET: **0x018**

**Reference:** RP2350 Datasheet Section 2.19.6.1 - SIO

---

### 6. **Pad Configuration**
**Problem:** GPIO pads start in isolated state and must be configured before use.

**Required Pad Settings:**
- Clear ISO (bit 8) - Remove pad isolation
- Set IE (bit 6) - Enable input buffer
- Clear OD (bit 7) - Enable output (not output disable)
- Value used: 0x56 (binary: 01010110)

**Pad Register Address:**
- PADS_BANK0_BASE (0x40038000) + 0x04 (skip voltage select) + (GPIO_NUM × 4)
- GPIO15: 0x40038000 + 0x04 + (15 × 4) = **0x40038040**

**Reference:** PADS_BANK0: GPIO0 Register

---

### 7. **Linker Script Section Order (THE FINAL ISSUE)**
**Problem:** Program booted but GPIO didn't work. All register settings were correct.

**Wrong Order:**
```ld
.image_def 0x10000000 : { KEEP(*(.image_def)) }
.vectors : { *(.vectors) }
```

**Correct Order:**
```ld
.text 0x10000000 : {
    KEEP(*(.vectors))      // Vector table FIRST
    KEEP(*(.image_def))    // Then IMAGE_DEF
    *(.text*)
}
```

**Why:** The bootrom expects to find the vector table at or near the start of the image. The IMAGE_DEF can follow after. Working examples all place vectors before IMAGE_DEF.

---

### 8. **CPU Architecture**
**Problem:** Cortex-M0+ doesn't support all instructions needed.

**Solution:** Use **cortex-m33** architecture with `.syntax unified`:
```assembly
.syntax unified
.cpu cortex-m33
.thumb
```

This enables instructions like `bics r3, r3, r1` (three-operand form).

---

## Complete Working Initialization Sequence

### Step 1: Release Peripherals from Reset
```assembly
ldr  r0, =0x40020000              // RESETS_BASE
ldr  r1, =((1 << 6) | (1 << 9))  // IO_BANK0 (bit 6) + PADS_BANK0 (bit 9)
ldr  r3, [r0, #0x0]               // Read RESET register
bics r3, r3, r1                   // Clear reset bits
str  r3, [r0, #0x0]               // Write back
```

### Step 2: Wait for Reset Complete
```assembly
_wait_reset:
    ldr  r3, [r0, #0x8]   // Read RESET_DONE register
    tst  r3, r1           // Test if both bits set
    beq  _wait_reset      // Loop until done
```

### Step 3: Configure Pad
```assembly
ldr  r3, =0x40038040  // PADS_BANK0 + GPIO15 offset
movs r2, #0x56        // Clear ISO, set IE, keep defaults
str  r2, [r3, #0]
```

### Step 4: Set GPIO Function to SIO
```assembly
ldr  r3, =0x4002807c  // IO_BANK0 + GPIO15_CTRL offset
movs r2, #5           // Function 5 = SIO
str  r2, [r3, #0]
```

### Step 5: Enable Output and Set High
```assembly
ldr  r0, =0xd0000000  // SIO_BASE
ldr  r1, =(1 << 15)   // GPIO15 mask
str  r1, [r0, #0x038] // GPIO_OE_SET - enable output
str  r1, [r0, #0x018] // GPIO_OUT_SET - set high
```

---

## Key Differences: RP2040 vs RP2350

| Feature | RP2040 | RP2350 |
|---------|--------|--------|
| Boot Method | boot2 required | IMAGE_DEF metadata |
| RESETS_BASE | 0x4000f000 | 0x40020000 |
| IO_BANK0_BASE | 0x40014000 | 0x40028000 |
| IO_BANK0 reset bit | 5 | 6 |
| PADS_BANK0 reset bit | 8 | 9 |
| GPIO_OE_SET offset | 0x024 | 0x038 |
| GPIO_OUT_SET offset | 0x014 | 0x018 |
| Architecture | Cortex-M0+ only | Cortex-M33 (Arm) or RISC-V |
| Coprocessor GPIO | No | Yes (optional) |

---

## Debugging Techniques Used

1. **Hexdump verification** - Checked binary for correct addresses
2. **Disassembly comparison** - Compared our code with working examples
3. **Reference examples** - Found and tested working bare-metal examples
4. **Datasheet verification** - Cross-referenced every register address and bit position
5. **Incremental testing** - Built working example first, then adapted

---

## Sources of Truth

1. **RP2350 Datasheet** - Official register definitions and addresses
2. **Working Examples:**
   - rp2350-bare-metal-arm-assembly (GitHub)
   - bare-metal-rp2350
   - rp2350-bare-metal-build

3. **Disassembly of SDK code** - Revealed coprocessor instructions and correct register usage

---

## Final Working Configuration

- **File:** rp2350_led.s (bare-metal ARM assembly)
- **Architecture:** Cortex-M33, unified syntax
- **Linker:** Custom script with vectors before IMAGE_DEF
- **Size:** ~160 bytes
- **Function:** Turns on GPIO15 LED on RP2350

The program successfully boots and controls the LED without any SDK dependencies.
