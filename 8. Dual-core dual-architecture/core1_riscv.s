# RISC-V Code for Core 1
# Assembled separately and included via .incbin

.section .text, "ax"
.global _start
_start:
    # Initialize stack pointer for RISC-V Core 1
    li sp, 0x20040000

    # Set GPIO15 LOW
    # SIO_BASE = 0xd0000000
    # GPIO_OUT_CLR offset = 0x20
    li t0, 0xd0000000     # SIO_BASE
    li t1, 0x8000         # Bit 15
    sw t1, 0x20(t0)       # GPIO_OUT_CLR

    # Stay in endless loop
1:
    j 1b
