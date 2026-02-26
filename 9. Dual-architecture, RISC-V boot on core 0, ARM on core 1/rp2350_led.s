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
    # Check which core we are
    csrr t0, mhartid
    bnez t0, core1_entry   # If core 1, branch to core 1 code

core0_init:
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

    # Configure GPIO15 pad
    li t0, 0x40038040      # PADS_BANK0 + GPIO15
    li t1, 0x56
    sw t1, 0(t0)

    # Set GPIO15 function to SIO
    li t0, 0x4002807c      # IO_BANK0 + GPIO15_CTRL
    li t1, 5               # Function 5 (SIO)
    sw t1, 0(t0)

    # Enable GPIO15 output
    li t0, 0xd0000000      # SIO_BASE
    li t1, 0x8000          # Bit 15
    sw t1, 0x38(t0)        # GPIO_OE_SET

    # Set GPIO HIGH
    li t0, 0xd0000000      # SIO_BASE
    li t1, 0x8000          # Bit 15
    sw t1, 0x18(t0)        # GPIO_OUT_SET

    # Small delay so we can see the HIGH
    li a0, 5000000
    call delay

    # Launch Core 1 (first time with RISC-V)
    li s0, 0xd0000000      # SIO_BASE
    la s1, core1_vector_table
    la s2, core1_entry
    li s3, 0x20040000      # Core 1 stack pointer
    li s4, 0               # Sequence counter
    li s5, 0               # Launch counter (0=first, 1=second)

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
    mv t2, s1
    j do_send

send_sp:
    mv t2, s3
    j do_send

send_entry:
    mv t2, s2
    # If this is the second launch (ARM), set Thumb bit (bit 0)
    li t0, 1
    bne s5, t0, do_send    # Skip if first launch (RISC-V)
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

    # Core 1 launched successfully!
    # Check if this is the second launch
    li t0, 1
    beq s5, t0, core0_main

    # First launch complete - wait longer than Core 1's delay
    li a0, 10000000
    call delay

    # Set GPIO HIGH again before resetting Core 1
    li t0, 0xd0000000      # SIO_BASE
    li t1, 0x8000          # Bit 15
    sw t1, 0x18(t0)        # GPIO_OUT_SET

    # Keep it HIGH for a visible duration
    li a0, 5000000
    call delay

    # Switch Core 1 to ARM architecture
    # OTP_ARCHSEL = 0x40120158
    # Bit 1 = Core 1 architecture (0=ARM, 1=RISC-V)
    li t0, 0x40120158      # OTP_ARCHSEL
    li t1, 0x00000000      # Clear bit 1 for Core 1 = ARM
    sw t1, 0(t0)

    # Reset Core 1 using PSM FRCE_OFF register
    # PSM_BASE = 0x40018000, FRCE_OFF offset = 0x4
    li t0, 0x40018004      # PSM_FRCE_OFF
    li t1, 0x01000000      # Bit 24 (PROC1)
    sw t1, 0(t0)

    # Wait a bit
    li a0, 100000
    call delay

    # Release Core 1 from reset
    li t0, 0x40018004      # PSM_FRCE_OFF
    li t1, 0
    sw t1, 0(t0)

    # Wait for reset to complete
    li a0, 1000000
    call delay

    # Drain FIFO before second launch
    li t0, 0xd0000000      # SIO_BASE
    li t1, 0x50
    add t1, t0, t1         # FIFO_ST address
drain_fifo_before_relaunch:
    lw t2, 0(t1)
    andi t2, t2, 1         # Check VLD bit
    beqz t2, fifo_drained
    lw t3, 0x58(t0)        # Read and discard from FIFO_RD
    j drain_fifo_before_relaunch
fifo_drained:

    # Now launch Core 1 again with ARM entry point
    li s0, 0xd0000000      # SIO_BASE
    la s1, core1_arm_entry # ARM vector table is at the start of ARM binary
    la s2, core1_arm_entry # ARM entry point is also the vector table address
    li s3, 0x20040000      # Core 1 stack pointer
    li s4, 0               # Reset sequence counter
    li s5, 1               # Mark as second launch
    j launch_loop

core0_main:
    j core0_main

reset_seq:
    li s4, 0
    j launch_loop

delay:
    addi a0, a0, -1
    bnez a0, delay
    ret

# CORE 1: RISC-V entry point
core1_entry:
    # Initialize stack pointer
    li sp, 0x20040000

    # Set GPIO LOW immediately
    li t0, 0xd0000000      # SIO_BASE
    li t1, 0x8000          # Bit 15
    sw t1, 0x20(t0)        # GPIO_OUT_CLR

    # Stay in endless loop
core1_done:
    j core1_done

# CORE 1: Vector table (not really used but part of protocol)
.align 8
core1_vector_table:
    .word core1_entry

# =============================================================================
# ARM CODE SECTION FOR CORE 1
# =============================================================================
.section .text.arm, "ax"
.align 4
.global core1_arm_entry
core1_arm_entry:
.incbin "build/core1_arm.bin"
