# RP2350 Dual-Architecture RISC-V Boot
# Core 0: RISC-V initializes and launches Core 1
# Core 1: First as RISC-V, then reset and switched to ARM

.section .image_def, "a"
    .word 0xffffded3  # BLOCK_MARKER_START
    .word 0x11010142  # IMAGE_TYPE: RISC-V executable for RP2350
    .word 0x00000344  # ENTRY_POINT item (type=0x44, size=3 words)
    .word _start      # Entry PC
    .word 0x20042000  # Stack pointer
    .word 0x000004ff  # LAST item (type=0xff, size=4 words total)
    .word 0x00000000  # Link to self
    .word 0xab123579  # BLOCK_MARKER_END

.section .text, "ax"
.global _start
_start:
    # Initialize stack pointer for core 0
    li sp, 0x20042000

    # Release IO_BANK0 and PADS_BANK0 from reset
    li t0, 0x40020000      # RESETS_BASE
    lw t1, 0(t0)
    li t2, ~((1 << 6) | (1 << 9))
    and t1, t1, t2
    sw t1, 0(t0)

    # Wait for reset done
    li t0, 0x40020008      # RESET_DONE register
    li t2, (1 << 6) | (1 << 9)
1:  lw t1, 0(t0)
    and t1, t1, t2
    bne t1, t2, 1b

    # Configure GPIO25 pad
    li t0, 0x40038068      # PADS_BANK0 + GPIO25
    li t1, 0x56
    sw t1, 0(t0)

    # Set GPIO25 function to SIO
    li t0, 0x400280cc      # IO_BANK0 + GPIO25_CTRL
    li t1, 5               # Function 5 (SIO)
    sw t1, 0(t0)

    # Enable GPIO25 output
    li t0, 0xd0000000      # SIO_BASE
    li t1, 0x02000000      # Bit 25
    sw t1, 0x38(t0)        # GPIO_OE_SET

    # Set GPIO HIGH initially
    li t0, 0xd0000000      # SIO_BASE
    li t1, 0x02000000      # Bit 25
    sw t1, 0x18(t0)        # GPIO_OUT_SET

    # Delay to show initial state
#    li a0, 5000000
#    call delay

    # Set Core 1 to ARM architecture
    # ARCHSEL must be set BEFORE releasing Core 1 from reset
    li t0, 0x40120158      # OTP_ARCHSEL
    li t1, 0x00000000      # Clear bit 1 for Core 1 = ARM
    sw t1, 0(t0)

    # Reset Core 1 using PSM FRCE_OFF so it samples the new ARCHSEL setting
    # PSM_BASE = 0x40018000, FRCE_OFF offset = 0x4
    li t0, 0x40018004      # PSM_FRCE_OFF
    li t1, 0x01000000      # Bit 24 (PROC1)
    sw t1, 0(t0)           # Force Core 1 into reset

    # Release Core 1 from reset by clearing the bit
    li t0, 0x40018004      # PSM_FRCE_OFF
    li t1, 0
    sw t1, 0(t0)

    # Launch Core 1 with ARM code
    li s0, 0xd0000000      # SIO_BASE
    la s1, core1_arm_entry # ARM vector table address
    la s2, core1_arm_entry # ARM entry point is the vector table address
    li s3, 0x20040000      # Core 1 stack pointer
    li s4, 0               # Sequence counter

launch_loop:
    # Determine which value to send
    li t2, 0
    beqz s4, send_0
    li t2, 1
    beq s4, t2, send_0
    li t2, 2
    beq s4, t2, send_1
    li t2, 3
    beq s4, t2, send_vt
    li t2, 4
    beq s4, t2, send_sp
    j send_entry

send_0:
    # Drain RX FIFO
    li t0, 0x50
    add t0, s0, t0
drain_loop:
    lw t1, 0(t0)
    andi t1, t1, 1
    beqz t1, drain_done
    lw t2, 0x58(s0)
    j drain_loop
drain_done:
    # h3.unblock instruction
    slt x0, x0, x1
    li t2, 0
    j do_send

send_1:
    li t2, 1
    j do_send

send_vt:
    mv t2, s1              # Vector table address (for ARM)
    j do_send

send_sp:
    mv t2, s3              # Stack pointer
    j do_send

send_entry:
    mv t2, s2              # Entry point
    ori t2, t2, 1          # Set bit 0 for ARM Thumb mode

do_send:
    # Wait for FIFO ready
wait_ready:
    lw t0, 0x50(s0)        # FIFO_ST
    andi t0, t0, 2         # Check RDY bit
    beqz t0, wait_ready

    # Send value
    sw t2, 0x54(s0)        # FIFO_WR

    # h3.unblock after write
    slt x0, x0, x1

    # Wait for response
wait_response:
    lw t0, 0x50(s0)
    andi t0, t0, 1         # Check VLD bit
    beqz t0, wait_response

    # Read response
    lw t3, 0x58(s0)        # FIFO_RD

    # Compare
    bne t2, t3, reset_seq

    # Match! Increment sequence
    addi s4, s4, 1
    li t0, 6
    bne s4, t0, launch_loop

    # Core 1 launched successfully - stay in infinite loop
core0_main:
    j core0_main

reset_seq:
    li s4, 0
    j launch_loop

#delay:
#    addi a0, a0, -1
#    bnez a0, delay
#    ret

# =============================================================================
# ARM CODE SECTION FOR CORE 1
# =============================================================================
.section .text.arm, "ax"
.align 4
.global core1_arm_entry
core1_arm_entry:
.incbin "build/core1_arm.bin"
