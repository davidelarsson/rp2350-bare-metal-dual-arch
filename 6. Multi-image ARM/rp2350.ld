MEMORY
{
    FLASH (rx) : ORIGIN = 0x10000000, LENGTH = 4M
    RAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 512K
}

SECTIONS
{
    /* Multi-image ARM layout - all in one section */
    .text 0x10000000 :
    {
        KEEP(*(.image_defs))
        *(.text*)
    } > FLASH
}
