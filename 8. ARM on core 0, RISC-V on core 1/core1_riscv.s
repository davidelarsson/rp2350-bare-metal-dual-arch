# RISC-V Code for Core 1
# Assembled separately and included via .incbin

.section .text, "ax"
.global _start
_start:
    # Initialize stack pointer for RISC-V Core 1
    li sp, 0x20040000

    # Blink LED
    li s0, 0xd0000000     # SIO_BASE
    li s1, 0x02000000     # Bit 25 for GPIO25

blink_loop:
    # Turn LED ON
    sw s1, 0x18(s0)       # GPIO_OUT_SET
    
    li a0, 2000000
    call delay

    # Turn LED OFF
    sw s1, 0x20(s0)       # GPIO_OUT_CLR
    
    li a0, 2000000
    call delay
    
    j blink_loop

delay:
    addi a0, a0, -1
    bnez a0, delay
    ret
