# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS { .text : { *(.text.bar) *(.text.foo)  } }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-objdump -s %t | FileCheck %s

# RUN: echo "SECTIONS { .text : { *(.text.foo) *(.text.bar) } }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-objdump -s %t | FileCheck --check-prefix=INV %s


# CHECK:      Contents of section .text:
# CHECK-NEXT: 02000000 00000000 01000000 00000000
# CHECK:      Contents of section .rodata:
# CHECK-NEXT: 02000000 00000000 01000000 00000000

# INV:      Contents of section .text:
# INV-NEXT: 01000000 00000000 02000000 00000000
# INV:      Contents of section .rodata:
# INV-NEXT: 01000000 00000000 02000000 00000000

.global _start
_start:

.section .text.bar,"a",@progbits
.quad 2
.section .text.foo,"a",@progbits
.quad 1
.section .rodata.foo,"ao",@progbits,.text.foo
.quad 1
.section .rodata.bar,"ao",@progbits,.text.bar
.quad 2
