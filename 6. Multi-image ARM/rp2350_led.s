// RP2350 Dual-Core Multi-Image ARM Test
// Testing which IMAGE_DEF gets executed when both are ARM
// Datasheet says: "the last one seen in linked-list order" wins

.syntax unified
.cpu cortex-m33
.thumb

// For ARM, each IMAGE_DEF needs its own vector table immediately preceding it
// All IMAGE_DEFs must be in the same section for linker to calculate offsets

.section .image_defs, "a"

// FIRST IMAGE_DEF: Stays HIGH
.align 8
vector_table_first:
    .word 0x20042000      // Initial stack pointer
    .word first_entry + 1 // Reset handler (+1 for Thumb mode)
    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  // Other vectors

image_def_first:
    .word 0xffffded3      // BLOCK_MARKER_START
    .word 0x10010142      // IMAGE_TYPE: ARM executable for RP2350
    .word 0x00000203      // VECTOR_TABLE item (type=0x03, size=2 words)
    .word vector_table_first  // Address of first vector table
    .word 0x000003ff      // LAST item (type=0xff, size=3 words: IMAGE_TYPE 1 + VECTOR_TABLE 2)
    .word image_def_second - image_def_first  // LINK: byte offset to next block
    .word 0xab123579      // BLOCK_MARKER_END

// SECOND IMAGE_DEF: Blinks
.align 8
vector_table_second:
    .word 0x20042000      // Initial stack pointer
    .word second_entry + 1 // Reset handler (+1 for Thumb mode)
    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  // Other vectors

.align 4
image_def_second:
    .word 0xffffded3      // BLOCK_MARKER_START
    .word 0x10010142      // IMAGE_TYPE: ARM executable for RP2350
    .word 0x00000203      // VECTOR_TABLE item (type=0x03, size=2 words)
    .word vector_table_second  // Address of second vector table
    .word 0x000003ff      // LAST item (type=0xff, size=3 words: IMAGE_TYPE 1 + VECTOR_TABLE 2)
    .word (image_def_first - image_def_second) & 0xFFFFFFFF  // LINK: byte offset back
    .word 0xab123579      // BLOCK_MARKER_END

// CODE SECTION
.section .text, "ax"

// FIRST ENTRY: Stays HIGH
.thumb_func
.global first_entry
first_entry:
    ldr sp, =0x20042000

    // Release IO_BANK0 and PADS_BANK0 from reset
    ldr r0, =0x40020000   // RESETS_BASE
    ldr r1, [r0]
    ldr r2, =~((1 << 6) | (1 << 9))
    and r1, r1, r2
    str r1, [r0]

    // Wait for reset done
    ldr r0, =0x40020008   // RESET_DONE register
    ldr r2, =((1 << 6) | (1 << 9))
1:  ldr r1, [r0]
    and r1, r1, r2
    cmp r1, r2
    bne 1b

    // Configure GPIO25 pad
    ldr r0, =0x40038068   // PADS_BANK0 + GPIO25
    mov r1, #0x56
    str r1, [r0]

    // Set GPIO25 function to SIO
    ldr r0, =0x400280cc   // IO_BANK0 + GPIO25_CTRL
    mov r1, #5            // Function 5 (SIO)
    str r1, [r0]

    // Enable GPIO25 output
    ldr r0, =0xd0000000   // SIO_BASE
    ldr r1, =0x02000000   // Bit 25
    str r1, [r0, #0x38]   // GPIO_OE_SET

    // Set GPIO HIGH and stay there
    str r1, [r0, #0x18]   // GPIO_OUT_SET
    
1:  b 1b

// SECOND ENTRY: Blinks
.thumb_func
.global second_entry
second_entry:
    ldr sp, =0x20042000

    // Release IO_BANK0 and PADS_BANK0 from reset
    ldr r0, =0x40020000   // RESETS_BASE
    ldr r1, [r0]
    ldr r2, =~((1 << 6) | (1 << 9))
    and r1, r1, r2
    str r1, [r0]

    // Wait for reset done
    ldr r0, =0x40020008   // RESET_DONE register
    ldr r2, =((1 << 6) | (1 << 9))
1:  ldr r1, [r0]
    and r1, r1, r2
    cmp r1, r2
    bne 1b

    // Configure GPIO25 pad
    ldr r0, =0x40038068   // PADS_BANK0 + GPIO25
    mov r1, #0x56
    str r1, [r0]

    // Set GPIO25 function to SIO
    ldr r0, =0x400280cc   // IO_BANK0 + GPIO25_CTRL
    mov r1, #5            // Function 5 (SIO)
    str r1, [r0]

    // Enable GPIO25 output
    ldr r0, =0xd0000000   // SIO_BASE
    ldr r1, =0x02000000   // Bit 25
    str r1, [r0, #0x38]   // GPIO_OE_SET

    // Blink LED
    ldr r4, =0xd0000000   // SIO_BASE
    ldr r5, =0x02000000   // Bit 25

blink_loop:
    // Turn LED ON
    str r5, [r4, #0x18]   // GPIO_OUT_SET

    ldr r0, =5000000
    bl delay

    // Turn LED OFF
    str r5, [r4, #0x20]   // GPIO_OUT_CLR

    ldr r0, =5000000
    bl delay

    b blink_loop

.thumb_func
delay:
    subs r0, r0, #1
    bne delay
    bx lr
