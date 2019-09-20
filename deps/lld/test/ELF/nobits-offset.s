# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64 %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -S -l %t | FileCheck %s

## If a SHT_NOBITS section is the only section of a PT_LOAD segment,
## p_offset will be set to the sh_offset field of the section. Check we align
## sh_offset to sh_addr modulo max-page-size, so that p_vaddr=p_offset (mod
## p_align).

# CHECK: Name Type   Address          Off     Size   ES Flg Lk Inf Al
# CHECK: .bss NOBITS 0000000000210000 010000  000001 00  WA  0   0 4096

# CHECK: Type Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align
# CHECK: LOAD 0x010000 0x0000000000210000 0x0000000000210000 0x000000 0x000001 RW  0x10000

# CHECK: 02 .bss

.bss
.p2align 12
.byte 0
