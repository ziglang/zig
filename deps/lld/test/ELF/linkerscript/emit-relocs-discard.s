# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { /DISCARD/ : { *(.bbb) } }" > %t.script
# RUN: ld.lld --emit-relocs --script %t.script %t.o -o %t1
# RUN: llvm-readobj -r %t1 | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT: ]

.section .aaa,"",@progbits
.Lfoo:

.section .bbb,"",@progbits
.long .Lfoo
