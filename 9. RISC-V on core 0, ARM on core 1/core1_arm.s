// ARM Code for Core 1
// Assembled separately and included via .incbin

.syntax unified
.cpu cortex-m33
.thumb

// ARM Core 1 Vector Table - must be at the start
.section .vectors, "ax"
.align 8
_start:
    .word 0x20040000      // Initial stack pointer for core 1
    .word core1_entry + 1 // Reset handler (+1 for Thumb)
    .word 0               // NMI
    .word 0               // HardFault
    .word 0               // MemManage
    .word 0               // BusFault
    .word 0               // UsageFault
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0

.section .text, "ax"
.thumb_func
core1_entry:
    // Initialize stack pointer for ARM Core 1
    ldr sp, =0x20040000

    // Blink LED
    ldr r4, =0xd0000000   // SIO_BASE
    ldr r5, =0x02000000   // Bit 25 for GPIO25

blink_loop:
    // Turn LED ON
    str r5, [r4, #0x18]   // GPIO_OUT_SET
    
    ldr r0, =1000000
    bl delay

    // Turn LED OFF
    str r5, [r4, #0x20]   // GPIO_OUT_CLR
    
    ldr r0, =1000000
    bl delay
    
    b blink_loop

delay:
    subs r0, r0, #1
    bne delay
    bx lr
