# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -l %t | FileCheck --check-prefix=SEG %s
# RUN: llvm-readelf -S %t | FileCheck %s

# We have 2 RW PT_LOAD segments. p_offset p_vaddr p_paddr p_filesz of the first
# should match PT_GNU_RELRO.
# Because .bss.rel.ro (nobits) doesn't take space, p_filesz < p_memsz.

#           Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align
# SEG:      LOAD           0x001000 0x0000000000201000 0x0000000000201000 0x000001 0x000001 R E 0x1000
# SEG-NEXT: LOAD           0x002000 0x0000000000202000 0x0000000000202000 0x000001 0x002001 RW  0x1000
# SEG-NEXT: LOAD           0x003000 0x0000000000205000 0x0000000000205000 0x000001 0x000002 RW  0x1000
# SEG-NEXT: GNU_RELRO      0x002000 0x0000000000202000 0x0000000000202000 0x000001 0x003000 R   0x1
# SEG-NEXT: GNU_STACK      0x000000 0x0000000000000000 0x0000000000000000 0x000000 0x000000 RW  0x0

# SEG:      .text
# SEG-NEXT: .data.rel.ro .bss.rel.ro
# SEG-NEXT: .data .bss

# And .data is placed in the next page (sh_offset = alignTo(0x2001, 4096) = 0x3000).

#        [Nr] Name              Type            Address          Off    Size
# CHECK:      .data.rel.ro      PROGBITS        0000000000202000 002000 000001
# CHECK-NEXT: .bss.rel.ro       NOBITS          0000000000202001 002001 002000
# CHECK-NEXT: .data             PROGBITS        0000000000205000 003000 000001
# CHECK-NEXT: .bss              NOBITS          0000000000205001 003001 000001

.globl _start
_start:
  ret

.section .data.rel.ro, "aw"
.space 1

.section .bss.rel.ro, "aw", @nobits
.space 8192

.section .data, "aw"
.space 1

.section .bss, "aw"
.space 1
