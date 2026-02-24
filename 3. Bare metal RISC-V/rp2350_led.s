.section .image_def, "a"
    .word 0xffffded3  # BLOCK_MARKER_START
    .word 0x11010142  # IMAGE_TYPE: RISC-V executable for RP2350 (1 word)

                      # Note that the following three words are not used in the ARM
                      # IMAGE_DEF; ARM has a vector table that contains this info instead.
    .word 0x00000344  # ENTRY_POINT item (type=0x44, size=3 words)
    .word _start      # Entry PC (will be resolved by linker)
    .word 0x20042000  # Stack pointer

    .word 0x000004ff  # LAST item (type=0xff, size=4 words total for all items)
    .word 0x00000000  # Next block pointer (0 = link to self)
    .word 0xab123579  # BLOCK_MARKER_END

# RISC-V gotchas
#
# lw/sw are load/store *words*, which means 4 bytes in RISC-V terminology!
#
# t0-t6 (x5-x7, x28-x31) are temporary registers by convention, meaning the
# caller should not expect them to be preserved across function calls.
# If we were to preserve values across calls, use s0-s11 (x8-x27) instead.
#
# `li` is a pseudo-instruction! A small value (that fits in 12 bits):
# li t1, 5 
# # becomes:
# addi t1, x0, 5
# A large value (that doesn't fit in 12 bits):
# li t0, 0x40020000
# # becomes:
# lui t0, 0x40020      # Note that t0 is hard-wired to zero!
# An even larger value (that doesn't fit in 20 bits):
# li t0, 0x40038040
# # becomes:
# lui t0, 0x40038   # lui = load upper immediate, which loads the top 20 bits and sets the bottom 12 bits to 0
# addi t0, t0, 0x40 # addi = add immediate, which adds the 12-bit immediate to the value in t0
.section .text, "ax"
.global _start
_start:
    # Initialize stack pointer
    li sp, 0x20042000
    # Release IO_BANK0 and PADS_BANK0 from reset
    li t0, 0x40020000      # RESETS_BASE (correct address!)
    lw t1, 0(t0)           # Read RESET register
    li t2, ~((1 << 6) | (1 << 9))  # Clear bits 6 (IO_BANK0) and 9 (PADS_BANK0)
    and t1, t1, t2
    sw t1, 0(t0)           # Write back

    # Wait for reset done
    li t0, 0x40020008      # RESET_DONE register
    li t2, (1 << 6) | (1 << 9)  # Bits 6 and 9
1:  lw t1, 0(t0)           # Load from RESET_DONE (correct!)
    and t1, t1, t2
    bne t1, t2, 1b         # Loop until both bits are set

    # Configure GPIO15 pad
    li t0, 0x40038040      # PADS_BANK0_BASE (0x40038000) + GPIO15 offset (0x40)
    li t1, 0x56            # IE=1, OD=0, ISO=0, reasonable drive/pull settings
    sw t1, 0(t0)

    # Set GPIO15 function to SIO
    li t0, 0x4002807c      # IO_BANK0_BASE (0x40028000) + GPIO15_CTRL (0x7c)
    li t1, 5               # Function 5 (SIO)
    sw t1, 0(t0)

    # Enable GPIO15 output
    li t0, 0xd0000000      # SIO_BASE
    li t1, 0x8000          # Bit 15 (GPIO15)
    sw t1, 0x38(t0)        # GPIO_OE_SET offset (0x038)

# Main blink loop
blink_loop:
    # Turn LED ON
    sw t1, 0x18(t0)        # GPIO_OUT_SET offset (0x018)
    call delay
    
    # Turn LED OFF
    sw t1, 0x20(t0)        # GPIO_OUT_CLR offset (0x020)
    call delay
    
    j blink_loop

# Delay function - approximately 1 second
delay:
    li t2, 5000000         # Delay count (~1 second)
delay_loop:
    addi t2, t2, -1
    bnez t2, delay_loop
    ret

# Minimal vector table (must be 256-byte aligned)
.align 8
.section .vectors, "a"
vector_table:
    .word 0x20042000       # Initial stack pointer
    .word _start           # Reset handler
    .rept 14
    .word _start           # All other exceptions point to start
    .endr
