// RP2350 Dual-Core ARM Test
// Core 0: Initialize GPIO25 and launch Core 1
// Core 1: Blink GPIO25

.syntax unified
.cpu cortex-m33
.thumb

// ARM IMAGE_DEF format is different from RISC-V
// ARM expects vector table immediately after IMAGE_DEF (no VECTOR_TABLE item needed)
.section .image_def, "a"
    .word 0xffffded3      // BLOCK_MARKER_START
    .word 0x10010142      // IMAGE_TYPE: ARM executable for RP2350
                          // 0x42 = PICOBIN_BLOCK_ITEM_1BS_IMAGE_TYPE
                          // 0x01 = size (1 word)
                          // 0x1001 = flags (IMAGE_TYPE_EXE | EXE_CPU_ARM | EXE_CHIP_RP2350)
    
    .word 0x000001ff      // LAST item (type=0xff, size=1 word for IMAGE_TYPE only)
    .word 0x00000000      // LINK: points to self
    .word 0xab123579      // BLOCK_MARKER_END

// ARM Cortex-M Vector Table
// First entry is initial stack pointer, second is reset handler
.section .vectors, "a"
.align 8
vector_table:
    .word 0x20042000      // Initial stack pointer (top of RAM)
    .word _start + 1      // Reset handler (+1 for Thumb mode)
    .word 0               // NMI
    .word 0               // HardFault
    .word 0               // MemManage
    .word 0               // BusFault
    .word 0               // UsageFault
    .word 0               // Reserved
    .word 0               // Reserved
    .word 0               // Reserved
    .word 0               // Reserved
    .word 0               // SVCall
    .word 0               // Debug Monitor
    .word 0               // Reserved
    .word 0               // PendSV
    .word 0               // SysTick

// =============================================================================
// RISC-V CODE SECTION FOR CORE 1
// =============================================================================
.section .text.riscv, "ax"
.align 4
.global core1_riscv_entry
core1_riscv_entry:
    // Include the separately assembled RISC-V binary
    .incbin "build/core1_riscv.bin"

.section .text, "ax"
.thumb_func
.global _start
_start:
    // Check which core we are on
    // For ARM, read SIO CPUID register at 0xd0000000
    ldr r0, =0xd0000000   // SIO_BASE
    ldr r0, [r0]          // Read CPUID (offset 0x000)
    cmp r0, #0
    bne core1_entry       // If core 1, branch to core 1 code

core0_init:
    // Initialize stack pointer for core 0
    ldr sp, =0x20042000

    // Release IO_BANK0 and PADS_BANK0 from reset
    ldr r0, =0x40020000   // RESETS_BASE
    ldr r1, [r0]          // Read RESET register
    ldr r2, =~((1 << 6) | (1 << 9))  // Clear bits 6 and 9
    and r1, r1, r2
    str r1, [r0]          // Write back

    // Wait for reset done
    ldr r0, =0x40020008   // RESET_DONE register
    ldr r2, =((1 << 6) | (1 << 9))
1:  ldr r1, [r0]
    and r1, r1, r2
    cmp r1, r2
    bne 1b                // Loop until both bits set

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
    str r1, [r0, #0x38]   // GPIO_OE_SET offset

    // TEST: Set GPIO HIGH immediately
    ldr r0, =0xd0000000   // SIO_BASE
    ldr r1, =0x02000000   // Bit 25
    str r1, [r0, #0x18]   // GPIO_OUT_SET

    // Delay
    ldr r0, =10000000
    bl delay

    // Launch Core 1
    ldr r4, =0xd0000000   // SIO_BASE
    ldr r5, =core1_vector_table
    ldr r6, =core1_entry
    ldr r7, =0x20040000   // Core 1 stack pointer
    mov r8, #0            // Sequence counter
    mov r9, #0            // Launch counter (0=first, 1=second)

// Send handshake sequence to wake core 1
launch_loop:
    // Determine which value to send
    cmp r8, #0
    beq send_0
    cmp r8, #1
    beq send_0
    cmp r8, #2
    beq send_1
    cmp r8, #3
    beq send_vt
    cmp r8, #4
    beq send_sp
    b send_entry

send_0:
    // Drain RX FIFO
    add r0, r4, #0x50     // FIFO_ST
drain_loop:
    ldr r1, [r0]
    tst r1, #1            // Check VLD bit
    beq drain_done
    ldr r2, [r4, #0x58]   // Read and discard from FIFO_RD
    b drain_loop
drain_done:
    // Execute SEV (ARM equivalent of h3.unblock)
    sev
    mov r2, #0
    b do_send

send_1:
    mov r2, #1
    b do_send

send_vt:
    mov r2, r5            // vector_table address
    b do_send

send_sp:
    mov r2, r7            // stack pointer
    b do_send

send_entry:
    mov r2, r6            // entry point (with Thumb bit set)
    orr r2, r2, #1        // Set bit 0 for Thumb mode

do_send:
    // Wait for FIFO ready
wait_ready:
    ldr r0, [r4, #0x50]   // FIFO_ST
    tst r0, #2            // Check RDY bit
    beq wait_ready

    // Send value
    str r2, [r4, #0x54]   // FIFO_WR

    // SEV after write
    sev

    // Wait for response
wait_response:
    ldr r0, [r4, #0x50]   // FIFO_ST
    tst r0, #1            // Check VLD bit
    beq wait_response

    // Read response
    ldr r3, [r4, #0x58]   // FIFO_RD

    // Compare
    cmp r2, r3
    bne reset_seq         // Mismatch, restart

    // Match! Increment sequence
    add r8, r8, #1
    cmp r8, #6
    bne launch_loop       // Continue if not done

    // Core 1 launched successfully!
    // Check if this is the second launch
    cmp r9, #1
    beq core0_main        // If second launch, enter infinite loop

    // First launch complete - wait longer than Core 1's delay (2x = 10000000)
    ldr r0, =10000000
    bl delay

    // Set GPIO HIGH again before resetting Core 1
    ldr r0, =0xd0000000   // SIO_BASE
    ldr r1, =0x02000000   // Bit 25
    str r1, [r0, #0x18]   // GPIO_OUT_SET

    // Keep it HIGH for a visible duration (same as Core 1's delay)
    ldr r0, =5000000
    bl delay

    // Switch Core 1 to RISC-V architecture
    // OTP_ARCHSEL = 0x40120158
    // Bit 1 = Core 1 architecture (0=ARM, 1=RISC-V)
    ldr r0, =0x40120158   // OTP_ARCHSEL
    mov r1, #0x00000002   // Set bit 1 for Core 1 = RISC-V
    str r1, [r0]

    // Reset Core 1 using PSM FRCE_OFF register
    // PSM_BASE = 0x40018000, FRCE_OFF offset = 0x4
    ldr r0, =0x40018004   // PSM_FRCE_OFF
    ldr r1, =0x01000000   // Bit 24 (PROC1)
    str r1, [r0]          // Force Core 1 into reset

    // Wait a bit
    ldr r0, =100000
    bl delay

    // Release Core 1 from reset by clearing the bit
    ldr r0, =0x40018004   // PSM_FRCE_OFF
    mov r1, #0
    str r1, [r0]

    // Wait for reset to complete
    ldr r0, =1000000
    bl delay

    // Now launch Core 1 again with RISC-V entry point
    ldr r4, =0xd0000000          // SIO_BASE
    ldr r5, =core1_vector_table  // Not used for RISC-V, but keep for protocol
    ldr r6, =core1_riscv_entry   // RISC-V entry point
    ldr r7, =0x20040000          // Core 1 stack pointer
    mov r8, #0                   // Sequence counter
    mov r9, #1                   // Mark as second launch
    b launch_loop                // Reuse the same launch loop

core0_main:
    b core0_main

reset_seq:
    // Restart handshake
    mov r8, #0
    b launch_loop

.thumb_func
delay:
    subs r0, r0, #1
    bne delay
    bx lr

// CORE 1: Entry point
.thumb_func
.align 4
core1_entry:
    // Core 1 starts here
    b core1_main

.thumb_func
.align 4
core1_main:
    // Initialize stack pointer
    ldr sp, =0x20040000

    // Set GPIO LOW immediately (no delay)
    ldr r4, =0xd0000000   // SIO_BASE
    ldr r5, =0x02000000   // Bit 25
    str r5, [r4, #0x20]   // GPIO_OUT_CLR

    // Stay in endless loop
core1_done:
    b core1_done

// CORE 1: Vector table
.align 8
core1_vector_table:
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
