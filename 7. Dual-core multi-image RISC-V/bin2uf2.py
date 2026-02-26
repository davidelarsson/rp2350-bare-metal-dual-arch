#!/usr/bin/env python3
"""Convert binary to UF2 format for RP2350 RISC-V"""

import sys
import struct

UF2_MAGIC_START0 = 0x0A324655
UF2_MAGIC_START1 = 0x9E5D5157
UF2_MAGIC_END = 0x0AB16F30
UF2_FLAG_FAMILY_ID_PRESENT = 0x00002000

RP2350_RISCV_FAMILY_ID = 0xe48bff5a  # RP2350 RISC-V

def convert_to_uf2(data, base_addr=0x10000000):
    """Convert binary data to UF2 format"""
    block_size = 256
    num_blocks = (len(data) + block_size - 1) // block_size
    uf2_data = bytearray()
    
    for block_num in range(num_blocks):
        offset = block_num * block_size
        chunk = data[offset:offset + block_size]
        if len(chunk) < block_size:
            chunk += b'\x00' * (block_size - len(chunk))
        
        # Build UF2 block (512 bytes)
        block = struct.pack('<IIIIIIII',
            UF2_MAGIC_START0,
            UF2_MAGIC_START1,
            UF2_FLAG_FAMILY_ID_PRESENT,
            base_addr + offset,
            block_size,
            block_num,
            num_blocks,
            RP2350_RISCV_FAMILY_ID
        )
        block += chunk
        block += b'\x00' * (476 - len(chunk))  # Pad to 476 bytes
        block += struct.pack('<I', UF2_MAGIC_END)
        
        uf2_data += block
    
    return bytes(uf2_data)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input.bin> <output.uf2>")
        sys.exit(1)
    
    with open(sys.argv[1], 'rb') as f:
        data = f.read()
    
    uf2 = convert_to_uf2(data, 0x10000000)
    
    with open(sys.argv[2], 'wb') as f:
        f.write(uf2)
    
    print(f"Converted {len(data)} bytes to UF2 ({len(uf2)} bytes, {len(uf2)//512} blocks)")
