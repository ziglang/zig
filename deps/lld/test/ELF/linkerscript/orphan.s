# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS {       \
# RUN:  .text : { *(.text) }  \
# RUN:  .rw1 : { *(.rw1) }    \
# RUN:  .rw2 : { *(.rw2) }    \
# RUN:  .rw3 : { *(.rw3) }    \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

## .jcr is a relro section and should be placed after other RW sections.
## .bss is SHT_NOBITS section and should be last RW section, so some space
## in ELF file could be saved.
# CHECK:       0               00000000 0000000000000000
# CHECK-NEXT:  1 .text         00000000 0000000000000000 TEXT
# CHECK-NEXT:  2 .rw1          00000008 0000000000000000 DATA
# CHECK-NEXT:  3 .rw2          00000008 0000000000000008 DATA
# CHECK-NEXT:  4 .rw3          00000008 0000000000000010 DATA
# CHECK-NEXT:  5 .jcr          00000008 0000000000000018 DATA
# CHECK-NEXT:  6 .bss          00000008 0000000000000020 BSS

.section .rw1, "aw"
 .quad 0

.section .rw2, "aw"
 .quad 0

.section .rw3, "aw"
 .quad 0

.section .jcr, "aw"
 .quad 0

.section .bss, "aw",@nobits
 .quad 0
