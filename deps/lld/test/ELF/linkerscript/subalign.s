# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o

# RUN: echo "SECTIONS { .aaa : { *(.aaa.*) } }" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %t1.o
# RUN: llvm-objdump -s %t1 | FileCheck -check-prefix=NOALIGN %s
# NOALIGN:      Contents of section .aaa:
# NOALIGN-NEXT:   01000000 00000000 00000000 00000000
# NOALIGN-NEXT:   00000000 00000000 00000000 00000000
# NOALIGN-NEXT:   02000000 00000000 00000000 00000000
# NOALIGN-NEXT:   00000000 00000000 00000000 00000000
# NOALIGN-NEXT:   03000000 00000000 00000000 00000000
# NOALIGN-NEXT:   00000000 00000000 00000000 00000000
# NOALIGN-NEXT:   00000000 00000000 00000000 00000000
# NOALIGN-NEXT:   00000000 00000000 00000000 00000000
# NOALIGN-NEXT:   04000000 00000000

# RUN: echo "SECTIONS { .aaa : SUBALIGN(1) { *(.aaa.*) } }" > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %t1.o
# RUN: llvm-objdump -s %t2 | FileCheck -check-prefix=SUBALIGN %s
# SUBALIGN: Contents of section .aaa:
# SUBALIGN:   01000000 00000000 02000000 00000000
# SUBALIGN:   03000000 00000000 04000000 00000000

.global _start
_start:
 nop

.section .aaa.1, "a"
.align 16
.quad 1

.section .aaa.2, "a"
.align 32
.quad 2

.section .aaa.3, "a"
.align 64
.quad 3

.section .aaa.4, "a"
.align 128
.quad 4
