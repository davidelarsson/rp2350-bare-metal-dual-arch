// RAM-only RP2350 LED blink - loads to 0x20000000
// Based on RP2350 IMAGE_DEF but targeting RAM

	.syntax unified
	.cpu cortex-m33
	.thumb

	// IMAGE_DEF metadata block
	.section .image_def, "a"
	.align 2
	.global image_def
image_def:
	.word 0xffffded3       // PICOBIN_BLOCK_MARKER_START
	.word 0x10210142       // IMAGE_TYPE: Arm, Secure, EXE, RP2350
	.word 0x000001ff       // LAST item, size=1
	.word 0x00000000       // Next block pointer (self-loop)
	.word 0xab123579       // PICOBIN_BLOCK_MARKER_END

	// Vector table
	.section .vectors, "ax"
	.align 8
	.global _vectors
_vectors:
	.word 0x20042000      // Initial Stack Pointer (middle of RAM)
	.word _reset+1        // Reset Handler (Thumb mode)
	// Minimal vector table
	.word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

	// Application code
	.section .text, "ax"
	.align 2
	.global _reset
	.thumb_func
_reset:
	// Set up stack pointer (redundant but safe)
	ldr r0, =0x20042000
	mov sp, r0

	// STEP 1: Release IO_BANK0 and PADS_BANK0 from reset
	ldr  r0, =0x40020000  // RESETS_BASE
	ldr  r1, =((1 << 6) | (1 << 9))  // IO_BANK0 (bit 6) + PADS_BANK0 (bit 9)
	ldr  r3, [r0, #0x0]   // Read RESET register
	bics r3, r3, r1       // Clear reset bits
	str  r3, [r0, #0x0]   // Write back

	// STEP 2: Wait for reset complete
_wait_reset:
	ldr  r3, [r0, #0x8]   // Read RESET_DONE
	tst  r3, r1           // Test both bits
	beq  _wait_reset      // Loop until done

	// STEP 3: Configure GPIO25 pad
	ldr  r3, =0x40038068  // PADS_BANK0 + GPIO25
	movs r2, #0x56        // Clear ISO, set IE
	str  r2, [r3, #0]

	// STEP 4: Set GPIO25 function to SIO
	ldr  r3, =0x400280cc  // IO_BANK0 + GPIO25_CTRL
	movs r2, #5           // Function 5 = SIO
	str  r2, [r3, #0]

	// STEP 5: Enable output and start blinking
	ldr  r0, =0xd0000000  // SIO_BASE
	ldr  r1, =(1 << 25)   // GPIO25 mask
	str  r1, [r0, #0x038] // GPIO_OE_SET

// Main blink loop
_blink_loop:
	str  r1, [r0, #0x018] // GPIO_OUT_SET (LED ON)
	bl   _delay
	
	str  r1, [r0, #0x020] // GPIO_OUT_CLR (LED OFF)
	bl   _delay
	
	b    _blink_loop

// Delay function
_delay:
	ldr  r2, =500000
_delay_loop:
	subs r2, r2, #1
	bne  _delay_loop
	bx   lr

.align 4
