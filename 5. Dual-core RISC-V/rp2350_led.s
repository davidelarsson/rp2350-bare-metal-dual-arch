# RP2350 Dual-Core RISC-V Test
# Core 0: Initialize GPIO25 and launch Core 1
# Core 1: Set GPIO25 HIGH and stay in infinite loop

.section .image_def, "a"
    .word 0xffffded3  # BLOCK_MARKER_START
    .word 0x11010142  # IMAGE_TYPE: RISC-V executable for RP2350
    .word 0x00000344  # ENTRY_POINT item (type=0x44, size=3 words)
    .word _start      # Entry PC (core 0 starts here)
    .word 0x20042000  # Stack pointer
    .word 0x000004ff  # LAST item (type=0xff, size=4 words total)
    .word 0x00000000  # Next block pointer (0 = link to self)
    .word 0xab123579  # BLOCK_MARKER_END

.section .text, "ax"
.global _start
_start:
    # Hart (HARdware Thread) is RISC-V terminology for a CPU core. Hart 0 = Core 0, etc.
    #
    # RISC-V has special CSRs (Control and Status Register) for system control that are
    # not memory-mapped. We read the mhartid CSR to determine which core we are on.
    #
    # Core 1 boots into a wait_for_vector function that sleep-waits for relevant data
    # to be sent from core 0 over the FIFO. When core 1 receives the correct sequence of data,
    # it will jump to the entry address sent by Core 0. The source of the wait_for_vector
    # function is documented in https://github.com/raspberrypi/pico-bootrom-rp2350
    #
    # How the wakeup sequence works is documented in the RP2350 datasheet
    # Section 5.3. "Launching code on Processor Core 1", but in C.
    #
    # Inter-core communication is done via a FIFO. Core 1 echoes back any data sent by core 0,
    # so core 0 can verify that core 1 is responding and in sync with the expected sequence.
    # If for some reason core 1 does not respond with the expected value, core 0 restarts the
    # sequence from the beginning.
    #
    # Hilarious Hazard3 hack:
    # In order to wake the other core up, you need to execute an `h3.unblock` instruction.
    # This is mapped to a seemingly random RISC-V opcode that would otherwise be a NOP:
    # slt x0, x0, x1
    # Since x0 is always zero, and any writes to it are ignored, this is always a NOP.
    # However, the RP2350 bootrom treats this instruction as a special signal to unblock
    # the other core.
    #
    # Check which core we are
    # csrr is a pseudo-instrution that reads a CSR into a register. Here we read mhartid into t0.
    # Assembles to: `csrrs t0, mhartid, x0` that means "read and clear bits that are set in x0"
    # x0 is always zero!
    csrr t0, mhartid
    bnez t0, core1_entry   # If core 1, branch to core 1 code
    
    # CORE 0: Initialize hardware and launch core 1
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

    # TEST: Set GPIO HIGH immediately to confirm hardware works
    li t0, 0xd0000000      # SIO_BASE
    li t1, 0x02000000      # Bit 25
    sw t1, 0x18(t0)        # GPIO_OUT_SET
    
    # Delay so we can see it
    li a0, 10000000
    call delay

    # Launch Core 1
    li s0, 0xd0000000      # SIO_BASE
    la s1, core1_vector_table
    la s2, core1_entry
    li s3, 0x20040000      # Core 1 stack pointer
    li s4, 0               # Sequence counter

# Datasheet 5.3. Launching code on Processor Core 1
# Send:
# seq 0: 0
# seq 1: 0
# seq 2: 1
# seq 3: vector table address (used to set mtvec on core 1)
# seq 4: initial stack pointer
# seq 5: entry point address
#
# vtvec: Machine Trap-Vector Base Address Register
# CSR = Control and Status Register
launch_loop:
    # Determine which value to send based on sequence counter
    li t2, 0
    beqz s4, send_0        # seq 0: send 0
    li t2, 1
    beq s4, t2, send_0     # seq 1: send 0
    li t2, 2
    beq s4, t2, send_1     # seq 2: send 1
    li t2, 3
    beq s4, t2, send_vt    # seq 3: send vector_table
    li t2, 4
    beq s4, t2, send_sp    # seq 4: send stack pointer
    j send_entry           # seq 5: send entry point

send_0:
    # Drain RX FIFO before sending 0
    li t0, 0x50
    add t0, s0, t0         # FIFO_ST address
drain_loop:
    lw t1, 0(t0)
    andi t1, t1, 1         # Check VLD bit
    beqz t1, drain_done
    lw t2, 0x58(s0)        # Read and discard from FIFO_RD
    j drain_loop
drain_done:
    # Execute h3.unblock (RISC-V equivalent of ARM's SEV)
    slt x0, x0, x1
    li t2, 0
    j do_send

send_1:
    li t2, 1
    j do_send

send_vt:
    mv t2, s1              # vector_table address
    j do_send

send_sp:
    mv t2, s3              # stack pointer
    j do_send

send_entry:
    mv t2, s2              # entry point address

do_send:
    # Wait for FIFO ready (RDY bit set)
wait_ready:
    lw t0, 0x50(s0)        # FIFO_ST
    andi t0, t0, 2         # Check RDY bit
    beqz t0, wait_ready
    
    # Send value
    sw t2, 0x54(s0)        # FIFO_WR
    
    # Execute h3.unblock after write (wake Core 1)
    slt x0, x0, x1

    # Wait for response (VLD bit set)
wait_response:
    lw t0, 0x50(s0)        # FIFO_ST
    andi t0, t0, 1         # Check VLD bit
    beqz t0, wait_response
    
    # Read response
    lw t3, 0x58(s0)        # FIFO_RD

    # Compare response with sent value
    bne t2, t3, reset_seq  # If mismatch, restart sequence
    
    # Match! Increment sequence
    addi s4, s4, 1
    li t0, 6
    bne s4, t0, launch_loop  # Continue if not done
    
    # Core 1 launched successfully! 
    # Core 0 is done - just infinite loop
core0_main:
    j core0_main

reset_seq:
    # Mismatch - restart handshake from beginning
    li s4, 0
    j launch_loop

delay:
    addi a0, a0, -1
    bnez a0, delay
    ret

core0_done:
    j core0_done

# CORE 1: Entry point after launch
.align 4
core1_entry:
    # Core 1 starts here when launched by core 0
    j core1_main

.align 4
core1_main:
    # Initialize stack pointer for core 1
    li sp, 0x20040000

    # Core 1: Blink LED at constant rate
    li s0, 0xd0000000      # SIO_BASE
    li s1, 0x02000000      # Bit 25 for GPIO25

core1_blink_loop:
    # Turn LED ON
    sw s1, 0x18(s0)        # GPIO_OUT_SET
    
    li a0, 5000000
    call delay
    
    # Turn LED OFF
    sw s1, 0x20(s0)        # GPIO_OUT_CLR
    
    li a0, 5000000
    call delay
    
    j core1_blink_loop

# CORE 1: Vector table (exception handlers - bootrom sets mtvec to this)
# Not actually used in this test since we don't trigger any exceptions,
# but required for bootrom to accept the image
.align 4
core1_vector_table:
    j core1_entry          # Exception handler 0
    .word 0                # Exception handler 1
    .word 0                # Exception handler 2
    .word 0                # Exception handler 3
    .word 0                # Exception handler 4
    .word 0                # Exception handler 5
    .word 0                # Exception handler 6
    .word 0                # Exception handler 7
    .word 0                # Exception handler 8
    .word 0                # Exception handler 9
    .word 0                # Exception handler 10
    .word 0                # Exception handler 11
    .word 0                # Exception handler 12
    .word 0                # Exception handler 13
    .word 0                # Exception handler 14
    .word 0                # Exception handler 15
