MEMORY
{
    FLASH (rx) : ORIGIN = 0x10000000, LENGTH = 4M
    RAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 512K
}

SECTIONS
{
    /* Vector table comes FIRST, then IMAGE_DEF (IMAGE_DEF must be in first 4KB) */
    .text 0x10000000 :
    {
        KEEP(*(.vectors))
        KEEP(*(.image_def))
        *(.text*)
    } > FLASH
}
