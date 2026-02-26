
	.syntax unified		// Modern unified syntax (there's an older "divided"
						// syntax but unified is more common now)
	.cpu cortex-m33		// Target Cortex-M33 core (RP2350)
	.thumb				// Irrelevant for Cortex-M but good practice to specify Thumb mode explicitly

	// IMAGE_DEF metadata block (must be in first 4KB)
	// .section is passed to the linker, so we can define custom sections for
	// the bootrom to find
	// .global makes the symbol visible to the outside (not used in this case
	// but good practice for clarity)
	.section .image_def, "a"	// "a" = allocatable (will be loaded into RAM by bootrom)
	.align 2			// Align to 4 bytes (32-bit words)
	.global image_def	// Make symbol global for bootrom to find
image_def:
	.word 0xffffded3       // PICOBIN_BLOCK_MARKER_START
	.word 0x10210142       // IMAGE_TYPE: Arm, Secure, EXE, RP2350
	.word 0x000001ff       // LAST item, size=1
	.word 0x00000000       // Next block pointer (self-loop)
	.word 0xab123579       // PICOBIN_BLOCK_MARKER_END

	// Vector table (bootrom will use this since no explicit entry point)
	.section .vectors, "ax"		// "a" = allocatable, "x" = executable
	.align 8			// Align to 8 bytes (64-bit) for Cortex-M33 vector table
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
	// ARM Thumb-2 (Cortex-M33) has limited immediate range; only 16-bit immediates.
	// `ldr` is a pseudo-instruction that the assembler will convert into
	// appropriate instruction(s), perhaps using a literal pool if needed
	// otherwise two mov instructions to construct the full 32-bit value
	// We let the assembler decide.
	ldr sp, =0x20082000

	// STEP 1: Release IO_BANK0 and PADS_BANK0 from reset. All peripherals are held
	// in reset by default, so we need to release them before we can be used.
	// RESETS_BASE = 0x40020000 (Page 32)
	// RESETS_RESET register offset = 0x0 (Page 506)
	// Bit 6 (IO_BANK0) and bit 9 (PADS_BANK0) according to page 506.
	//
	// Note that all GPIO pins are in Bank 0. (As described in chapter 9.1)
	//
	// bics = Bit Clear with Set flags (there is also a 'bic' instruction that
	// doesn't update flags)
	// bics r3, r3, r1       // r3 = r3 & ~r1 (clear bits in r1)
	//
	ldr  r0, =0x40020000  // RESETS_BASE
	ldr  r1, =((1 << 6) | (1 << 9))  // Bits 6 (IO_BANK0) and 9 (PADS_BANK0)
	ldr  r3, [r0, #0x0]   // Read current RESETS_RESET register
	bics r3, r3, r1       // Clear the reset bits (release from reset)
	str  r3, [r0, #0x0]   // Write back

	// STEP 2: Wait for both resets to complete
	// Reference: RESETS: RESET_DONE Register (Offset 0x8, page 505)
	// Must wait for bits 6 and 9 to be set before proceeding
_wait_reset:
	ldr  r3, [r0, #0x8]   // Load RESET_DONE register
	tst  r3, r1           // Test if both bits 6 and 9 are set
	beq  _wait_reset      // Loop until both are done

	// STEP 3: Configure GPIO25 pad control
	// PADS_BANK0_BASE = 0x40038000 (Page 32)
	// GPIO25 offset = 0x68 (0x04 base + GPIO_number * 4), page 799
	// Bit 8 (ISO) must be cleared to remove pad isolation
	// Bit 6 (IE) must be set to enable input
	// Bit 7 (OD) must be 0 to enable output
	ldr  r3, =0x40038068  // PADS_BANK0_BASE (0x40038000) + GPIO25 (0x68)
	movs r2, #0x56        // Binary: 0101 0110 = IE=1, OD=0, ISO=0,
					      // DRIVE=01 (4mA), PDE=1, SCHMITT=1, SLEWFAST=0
	str  r2, [r3, #0]

	// STEP 4: Set GPIO25 function to SIO (Software Controlled I/O)
	// IO_BANK0_BASE = 0x40028000 (Page 32)
	// GPIO25_CTRL Register offset = 0xCC (0x04 base + GPIO_number * 8)
	// FUNCSEL bits [4:0] = 0x05 → SIO_25
	ldr  r3, =0x400280cc  // IO_BANK0_BASE (0x40028000) + GPIO25_CTRL (0xCC)
						  // Page 651 in the datasheet
	movs r2, #5           // Function 5 = SIO
	str  r2, [r3, #0]

	// STEP 5: Enable GPIO25 as output and set it high
	// SIO_BASE = 0xd0000000 (Page 34)
	// SIO GPIO_OE_SET offset = 0x038 (set output enable bits, page 65)
	// SIO GPIO_OUT_SET offset = 0x018 (set output value bits, page 62)
	// SIO GPIO_OUT_CLR offset = 0x020 (clear output value bits, page 63)
	
	// Enable GPIO25 as output
	ldr  r0, =0xd0000000  // SIO_BASE
	ldr  r1, =(1 << 25)   // Bit 25 for GPIO25
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
	ldr  r2, =5000000     // Delay count (~1 second)
_delay_loop:
	subs r2, r2, #1
	bne  _delay_loop
	bx   lr

.align 4
