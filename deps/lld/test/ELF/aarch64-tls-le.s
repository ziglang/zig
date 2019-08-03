# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %s -o %tmain.o
# RUN: ld.lld %tmain.o -o %tout
# RUN: llvm-objdump -d %tout | FileCheck %s
# RUN: llvm-readobj -S -r %tout | FileCheck -check-prefix=RELOC %s

#Local-Dynamic to Local-Exec relax creates no
#RELOC:      Relocations [
#RELOC-NEXT: ]

.globl _start
_start:
 mrs x0, TPIDR_EL0
 add x0, x0, :tprel_hi12:v1
 add x0, x0, :tprel_lo12_nc:v1
 mrs x0, TPIDR_EL0
 add x0, x0, :tprel_hi12:v2
 add x0, x0, :tprel_lo12_nc:v2

# TCB size = 0x16 and foo is first element from TLS register.
#CHECK: Disassembly of section .text:
#CHECK: _start:
#CHECK:  210000: 40 d0 3b d5     mrs     x0, TPIDR_EL0
#CHECK:  210004: 00 00 40 91     add     x0, x0, #0, lsl #12
#CHECK:  210008: 00 40 00 91     add     x0, x0, #16
#CHECK:  21000c: 40 d0 3b d5     mrs     x0, TPIDR_EL0
#CHECK:  210010: 00 fc 7f 91     add     x0, x0, #4095, lsl #12
#CHECK:  210014: 00 e0 3f 91     add     x0, x0, #4088

.section        .tbss,"awT",@nobits

.type   v1,@object
.globl  v1
.p2align 2
v1:
.word  0
.size  v1, 4

# The current offset from the thread pointer is 20. Raise it to just below the
# 24-bit limit.
.space (0xfffff8 - 20)

.type   v2,@object
.globl  v2
.p2align 2
v2:
.word  0
.size  v2, 4
