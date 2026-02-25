# RP2350 Dual-Core Multi-Image RISC-V Debug
# Testing which IMAGE_DEF gets executed when both are RISC-V
# Datasheet says: "the last one seen in linked-list order" wins

# Blocks (images or partitions) start on a word-aligned boundary, which in RISC-V
# means 4 bytes.
# The total size is always an exact number of words (a multiple of four bytes).
#
# Due to RAM restrictions in the boot path, size of blocks is limited to 640 bytes for PARTITION_TABLEs and 384 bytes for
# IMAGE_DEFs. Blocks larger than this are ignored.
#

#
# IMAGE_DEF items:
# (Note that the size_flag/size_type (bit 7) of the first byte of the image type is
# part of the image type definition, so the size of the image type field is either
# 1 or 2 bytes depending on the image type.)
#
# - BLOCK_MARKER_START (0xffffded3)
#
# - IMAGE_TYPE
#   42     = item_type = PICOBIN_BLOCK_ITEM_1BS_IMAGE_TYPE, size_flag = 0
#            size_flag (bit 7) (0 means 1-byte size, 1 means 2-byte size), item_type:7
#            Note that size_flag is part of the image type definition, so nothing
#            we have to worry about ourselves.
#   01     = Block size: 1 word (4 bytes)
#   0x1101 = flags:
#       bits 0-2: Image Type (0x01 = IMAGE_TYPE_EXE, 0x02 = IMAGE_TYPE_DATA)
#       ...
#       bits 8-10: EXE CPU (0x0 = EXE_CPU_ARM, 0x1 = EXE_CPU_RISCV)
#       ...
# 
# - ENTRY_POINT
#  0x44     = size_flag == 0, item_type == PICOBIN_BLOCK_ITEM_1BS_ENTRY_POINT
#  0x03     = size of the item data in words (3 words = 12 bytes)
#  0x0000   = pad
#  first_entry = entry PC (value will be resolved by linker)
#  0x20042000 = stack pointer
# In total: 12 bytes.
#
# - LAST_ITEM
# 0xff     = item_type == PICOBIN_BLOCK_ITEM_1BS_LAST (PICOBIN_BLOCK_ITEM_LAST)
# 0x0004   = size of all other items in the block excluding BLOCK_MARKER_START,
#            LAST_ITEM, LINK and FOOTER
# 0x00     = pad
#
# - LINK
#   4 bytes: offset in bytes from the start of this block to the start of the
#            next block
#
#  BLOCK_MARKER_END (0xab123579)

.section .image_def, "a"
image_def_first:
    .word 0xffffded3  # BLOCK_MARKER_START
    .word 0x11010142  # IMAGE_TYPE: RISC-V executable
    .word 0x00000344  # ENTRY_POINT item (type=0x44, size=3 words)
    .word first_entry # Entry PC - stays HIGH
    .word 0x20042000  # Stack pointer
    .word 0x000004ff  # LAST item (type=0xff, size=4 words total)
    .word image_def_second - image_def_first  # BYTE offset to next block
    .word 0xab123579  # BLOCK_MARKER_END

.align 4
image_def_second:
    .word 0xffffded3  # BLOCK_MARKER_START
    .word 0x11010142  # IMAGE_TYPE: RISC-V executable
    .word 0x00000344  # ENTRY_POINT item (type=0x44, size=3 words)
    .word second_entry # Entry PC - blinks
    .word 0x20042000  # Stack pointer
    .word 0x000004ff  # LAST item (type=0xff, size=4 words total)
    .word (image_def_first - image_def_second) & 0xFFFFFFFF  # BYTE offset back
    .word 0xab123579  # BLOCK_MARKER_END

.section .text, "ax"
.global first_entry
first_entry:
    # FIRST IMAGE_DEF entry point - stays HIGH
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

    # Set GPIO HIGH and stay there
    sw t1, 0x18(t0)        # GPIO_OUT_SET
    
1:  j 1b

.global second_entry
second_entry:
    # SECOND IMAGE_DEF entry point - blinks
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

# Blink loop
blink_loop:
    # Turn LED ON
    sw t1, 0x18(t0)        # GPIO_OUT_SET
    call delay
    
    # Turn LED OFF
    sw t1, 0x20(t0)        # GPIO_OUT_CLR
    call delay
    
    j blink_loop

# Delay function
delay:
    li t2, 5000000         # ~1 second
delay_loop:
    addi t2, t2, -1
    bnez t2, delay_loop
    ret
