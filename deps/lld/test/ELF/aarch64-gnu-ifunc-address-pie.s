# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %s -o %t.o
# RUN: ld.lld -pie %t.o -o %tout
# RUN: llvm-objdump -D %tout | FileCheck %s
# RUN: llvm-readobj -r %tout | FileCheck %s -check-prefix=CHECK-RELOCS

# Test that when we take the address of a preemptible ifunc using -fpie, we can
# handle the case when the ifunc is in the same translation unit as the address
# taker. In this case the compiler knows that ifunc is not defined in a shared
# library so it can use a non got generating relative reference.
.text
.globl myfunc
.type myfunc,@gnu_indirect_function
myfunc:
 ret

.text
.globl main
.type main,@function
main:
 adrp x8, myfunc
 add  x8, x8, :lo12: myfunc
 ret

# CHECK: 0000000000010000 myfunc:
# CHECK-NEXT:    10000:	c0 03 5f d6 	ret
# CHECK: 0000000000010004 main:
# CHECK-NEXT:    10004:	08 00 00 90 	adrp	x8, #0
# x8 = 0x10000
# CHECK-NEXT:    10008:	08 41 00 91 	add	x8, x8, #16
# x8 = 0x10010 = .plt for myfunc
# CHECK-NEXT:    1000c:	c0 03 5f d6 	ret
# CHECK-NEXT: Disassembly of section .plt:
# CHECK-NEXT: 0000000000010010 .plt:
# CHECK-NEXT:    10010:	90 00 00 90 	adrp	x16, #65536
# CHECK-NEXT:    10014:	11 02 40 f9 	ldr	x17, [x16]
# CHECK-NEXT:    10018:	10 02 00 91 	add	x16, x16, #0
# CHECK-NEXT:    1001c:	20 02 1f d6 	br	x17

# CHECK-RELOCS: Relocations [
# CHECK-RELOCS-NEXT:   Section {{.*}} .rela.plt {
# CHECK-RELOCS-NEXT:     0x20000 R_AARCH64_IRELATIVE - 0x10000
# CHECK-RELOCS-NEXT:   }
# CHECK-RELOCS-NEXT: ]
