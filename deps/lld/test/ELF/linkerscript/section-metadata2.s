# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { .text : { *(.text.*) } }" > %t.script

# RUN: echo "_bar" > %t.ord
# RUN: echo "_foo" >> %t.ord
# RUN: ld.lld --symbol-ordering-file %t.ord -o %t --script %t.script %t.o
# RUN: llvm-objdump -s %t | FileCheck %s

# CHECK:      Contents of section .rodata:
# CHECK-NEXT: 02000000 00000000 01000000 00000000
# CHECK:      Contents of section .text:
# CHECK-NEXT: 02000000 00000000 01000000 00000000

# RUN: echo "_foo" > %t.ord
# RUN: echo "_bar" >> %t.ord
# RUN: ld.lld --symbol-ordering-file %t.ord -o %t --script %t.script %t.o
# RUN: llvm-objdump -s %t | FileCheck %s --check-prefix=INV

# INV:      Contents of section .rodata:
# INV-NEXT: 01000000 00000000 02000000 00000000
# INV:      Contents of section .text:
# INV-NEXT: 01000000 00000000 02000000 00000000

.section .text.foo,"a",@progbits
_foo:
.quad 1

.section .text.bar,"a",@progbits
_bar:
.quad 2

.section .rodata.foo,"ao",@progbits,.text.foo
.quad 1

.section .rodata.bar,"ao",@progbits,.text.bar
.quad 2
