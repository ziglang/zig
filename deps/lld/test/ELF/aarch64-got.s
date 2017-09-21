# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readobj -s %t | FileCheck %s

# CHECK-NOT: Name: .got

.globl _start
_start:
 adrp    x0, :gottprel:foo

	.global foo
 .section .tdata,"awT",%progbits
 .align 2
 .type foo, %object
 .size foo, 4
foo:
 .word 5
