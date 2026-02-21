// Bare-metal RP2350 with proper IMAGE_DEF metadata
// No boot2 required! RP2350 bootrom sets up XIP automatically

	.syntax unified
	.cpu cortex-m33
	.thumb

	// IMAGE_DEF metadata block (must be in first 4KB)
	.section .image_def, "a"
	.align 2
	.global image_def
image_def:
	.word 0xffffded3       // PICOBIN_BLOCK_MARKER_START
	.word 0x10210142       // IMAGE_TYPE: Arm, Secure, EXE, RP2350
	.word 0x000001ff       // LAST item, size=1
	.word 0x00000000       // Next block pointer (self-loop)
	.word 0xab123579       // PICOBIN_BLOCK_MARKER_END

	// Vector table (bootrom will use this since no explicit entry point)
	.section .vectors, "ax"
	.align 8
	.global _vectors
_vectors:
	.word 0x20082000      // Initial Stack Pointer
	.word _reset+1        // Reset Handler (Thumb mode)
	// Minimal vector table - rest can be zeros
	.word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  // Other vectors

	// Application code
	.section .text, "ax"
	.align 2
	.global _reset
	.thumb_func
_reset:
	// Set up stack pointer
	ldr r0, =0x20082000
	mov sp, r0

	// STEP 1: Release IO_BANK0 and PADS_BANK0 from reset
	// Reference: RP2350 Datasheet Section 2.2 (Address Map) - RESETS_BASE = 0x40020000
	// Reference: RESETS: RESET Register (Offset 0x0)
	//   - Bit 6 = IO_BANK0
	//   - Bit 9 = PADS_BANK0
	// Read-modify-write: clear the bits to release from reset
	ldr  r0, =0x40020000  // RESETS_BASE
	ldr  r1, =((1 << 6) | (1 << 9))  // Bits 6 (IO_BANK0) and 9 (PADS_BANK0)
	ldr  r3, [r0, #0x0]   // Read current RESET register
	bics r3, r3, r1       // Clear the reset bits (release from reset)
	str  r3, [r0, #0x0]   // Write back

	// STEP 2: Wait for both resets to complete
	// Reference: RESETS: RESET_DONE Register (Offset 0x8)
	// Must wait for bits 6 and 9 to be set before proceeding
_wait_reset:
	ldr  r3, [r0, #0x8]   // Load RESET_DONE register
	tst  r3, r1           // Test if both bits 6 and 9 are set
	beq  _wait_reset      // Loop until both are done

	// STEP 3: Configure GPIO15 pad control
	// Reference: Section 2.2 - PADS_BANK0_BASE = 0x40038000
	// Reference: PADS_BANK0: GPIO0 Register (Offset 0x04, then +4 per GPIO)
	//   GPIO15 offset = 0x04 + (15 * 4) = 0x04 + 0x3C = 0x40
	// Bit 8 (ISO) must be cleared to remove pad isolation
	// Bit 6 (IE) must be set to enable input
	// Bit 7 (OD) must be 0 to enable output
	ldr  r3, =0x40038040  // PADS_BANK0_BASE (0x40038000) + GPIO15 (0x40)
	movs r2, #0x56        // Binary: 0101 0110 = IE=1, OD=0, ISO=0, DRIVE=01 (4mA), PDE=1, SCHMITT=1, SLEWFAST=0
	str  r2, [r3, #0]

	// STEP 4: Set GPIO15 function to SIO (Software Controlled I/O)
	// Reference: Section 2.2 - IO_BANK0_BASE = 0x40028000
	// Reference: IO_BANK0: GPIO0_CTRL Register (Offset 0x04, then +8 per GPIO)
	//   GPIO15 CTRL offset = 0x04 + (15 * 8) = 0x04 + 0x78 = 0x7C
	// FUNCSEL bits [4:0] = 5 for SIO function
	ldr  r3, =0x4002807c  // IO_BANK0_BASE (0x40028000) + GPIO15_CTRL (0x7C)
	movs r2, #5           // Function 5 = SIO
	str  r2, [r3, #0]

	// STEP 5: Enable GPIO15 as output and set it high
	// Reference: Section 2.19.6.1 - SIO_BASE = 0xd0000000
	// SIO GPIO_OE_SET offset = 0x038 (set output enable bits)
	// SIO GPIO_OUT_SET offset = 0x018 (set output value bits)
	// SIO GPIO_OUT_CLR offset = 0x020 (clear output value bits)
	
	// Enable GPIO15 as output
	ldr  r0, =0xd0000000  // SIO_BASE
	ldr  r1, =(1 << 15)   // Bit 15 for GPIO15
	str  r1, [r0, #0x038] // GPIO_OE_SET

// Main blink loop
_blink_loop:
	// Turn LED ON
	str  r1, [r0, #0x018] // GPIO_OUT_SET
	bl   _delay
	
	// Turn LED OFF
	str  r1, [r0, #0x020] // GPIO_OUT_CLR
	bl   _delay
	
	b    _blink_loop

// Delay function - approximately 1 second at default clock speed
_delay:
	ldr  r2, =2000000     // Delay count (~1 second)
_delay_loop:
	subs r2, r2, #1
	bne  _delay_loop
	bx   lr

.align 4
