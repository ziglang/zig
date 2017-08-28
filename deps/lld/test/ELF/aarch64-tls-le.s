# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %s -o %tmain.o
# RUN: ld.lld %tmain.o -o %tout
# RUN: llvm-objdump -d %tout | FileCheck %s
# RUN: llvm-readobj -s -r %tout | FileCheck -check-prefix=RELOC %s
# REQUIRES: aarch64

#Local-Dynamic to Initial-Exec relax creates no
#RELOC:      Relocations [
#RELOC-NEXT: ]

.globl _start
_start:
 mrs x0, TPIDR_EL0
 add x0, x0, :tprel_hi12:v1
 add x0, x0, :tprel_lo12_nc:v1

# TCB size = 0x16 and foo is first element from TLS register.
#CHECK: Disassembly of section .text:
#CHECK: _start:
#CHECK:  20000: 40 d0 3b d5     mrs     x0, TPIDR_EL0
#CHECK:  20004: 00 00 40 91     add     x0, x0, #0, lsl #12
#CHECK:  20008: 00 40 00 91     add     x0, x0, #16

.type   v1,@object
.section        .tbss,"awT",@nobits
.globl  v1
.p2align 2
v1:
.word  0
.size  v1, 4

