MEMORY
{
    FLASH (rx) : ORIGIN = 0x10000000, LENGTH = 4M
    RAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 512K
}

SECTIONS
{
    . = 0x10000000;
    
    .image_def : {
        KEEP(*(.image_def))
    } > FLASH
    
    .text : ALIGN(4) {
        *(.text*)
    } > FLASH
    
    .vectors : ALIGN(256) {
        KEEP(*(.vectors))
    } > FLASH
}
