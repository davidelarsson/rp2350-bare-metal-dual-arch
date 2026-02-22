/* Linker script for RP2350 RAM-only execution */

MEMORY
{
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 264K  /* Main RAM up to 0x20042000 */
}

SECTIONS
{
    /* Everything goes into RAM, starting at 0x20000000 */
    .text 0x20000000 :
    {
        KEEP(*(.vectors))
        KEEP(*(.image_def))
        *(.text*)
        *(.rodata*)
    } > RAM

    .data :
    {
        *(.data*)
    } > RAM

    .bss :
    {
        *(.bss*)
        *(COMMON)
    } > RAM
}

