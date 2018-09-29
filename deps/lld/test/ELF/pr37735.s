# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux-gnu %s -o %t.o
# RUN: ld.lld -r %t.o %t.o -o %t1.o
# RUN: llvm-objdump -s -section=.bar %t1.o | FileCheck %s

.section .foo
	.byte 0

# CHECK:      Contents of section .bar:
# CHECK-NEXT:  0000 00000000 01000000
.section .bar
	.dc.a .foo
