# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:         foo = 123; \
# RUN:         . = 0x1000; \
# RUN:         . = 0x2000; \
# RUN:         .bar : { *(.bar) } \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t -T %t.script %t.o -shared
# RUN: llvm-readobj -s %t | FileCheck %s

# CHECK:      Name: .text
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_EXECINSTR
# CHECK-NEXT: ]
# CHECK-NEXT: Address: 0x1000

.section .bar, "aw"
