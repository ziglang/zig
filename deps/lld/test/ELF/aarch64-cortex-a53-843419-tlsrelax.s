// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux %s -o %t.o
// RUN: ld.lld -fix-cortex-a53-843419 %t.o -o %t2
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t2 | FileCheck %s

// The following code sequence is covered by the TLS IE to LE relaxation. It
// transforms the ADRP, LDR to MOVZ, MOVK. The former can trigger a
// cortex-a53-843419 patch, whereas the latter can not. As both
// relaxation and patching transform instructions very late in the
// link there is a possibility of them both being simultaneously
// applied. In this case the relaxed sequence is immune from the erratum so we
// prefer to keep it.
 .text
 .balign 4096
 .space  4096 - 8
 .globl _start
 .type  _start,@function
_start:
 mrs    x1, tpidr_el0
 adrp   x0, :gottprel:v
 ldr    x1, [x0, #:gottprel_lo12:v]
 adrp   x0, :gottprel:v
 ldr    x1, [x0, #:gottprel_lo12:v]
 ret

// CHECK: _start:
// CHECK-NEXT:   210ff8:        41 d0 3b d5     mrs     x1, TPIDR_EL0
// CHECK-NEXT:   210ffc:        00 00 a0 d2     movz    x0, #0, lsl #16
// CHECK-NEXT:   211000:        01 02 80 f2     movk    x1, #16
// CHECK-NEXT:   211004:        00 00 a0 d2     movz    x0, #0, lsl #16
// CHECK-NEXT:   211008:        01 02 80 f2     movk    x1, #16
// CHECK-NEXT:   21100c:        c0 03 5f d6     ret

 .type  v,@object
 .section       .tbss,"awT",@nobits
 .globl v
v:
 .word 0
