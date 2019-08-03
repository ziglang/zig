// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux %s -o %t.o
// RUN: ld.lld --fix-cortex-a53-843419 %t.o -o %t2
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t2 -start-address=2162688   -stop-address=2162700   | FileCheck --check-prefix=CHECK1 %s
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t2 -start-address=2166784   -stop-address=2166788   | FileCheck --check-prefix=CHECK2 %s
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t2 -start-address=2170872   -stop-address=2170888   | FileCheck --check-prefix=CHECK3 %s
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t2 -start-address=69287928  -stop-address=69287944  | FileCheck --check-prefix=CHECK4 %s
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t2 -start-address=102842376 -stop-address=102842392 | FileCheck --check-prefix=CHECK5 %s
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t2 -start-address=136384524 -stop-address=136384528 | FileCheck --check-prefix=CHECK6 %s
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t2 -start-address=136388604 -stop-address=136388628 | FileCheck --check-prefix=CHECK7 %s
// Test case for Cortex-A53 Erratum 843419 in an OutputSection exceeding
// the maximum branch range. Both range extension thunks and patches are
// required.					      
						      
// CHECK1:  __AArch64AbsLongThunk_need_thunk_after_patch:
// CHECK1-NEXT:    210000:       50 00 00 58     ldr     x16, #8
// CHECK1-NEXT:    210004:       00 02 1f d6     br      x16
// CHECK1: $d:					      
// CHECK1-NEXT:    210008:       0c 10 21 08     .word   0x0821100c
						      
        .section .text.01, "ax", %progbits
        .balign 4096
        .globl _start
        .type _start, %function
_start:
        // Expect thunk on pass 2
        bl need_thunk_after_patch
        .section .text.02, "ax", %progbits
        .space 4096 - 12

// CHECK2: _start:
// CHECK2-NEXT:    211000:       00 fc ff 97     bl      #-4096

        // Expect patch on pass 1
        .section .text.03, "ax", %progbits
        .globl t3_ff8_ldr
        .type t3_ff8_ldr, %function
t3_ff8_ldr:
        adrp x0, dat
        ldr x1, [x1, #0]
        ldr x0, [x0, :got_lo12:dat]
        ret

// CHECK3: t3_ff8_ldr:
// CHECK3-NEXT:    211ff8:       e0 00 04 f0     adrp    x0, #134344704
// CHECK3-NEXT:    211ffc:       21 00 40 f9     ldr     x1, [x1]
// CHECK3-NEXT:    212000:       02 08 80 15     b       #100671496
// CHECK3-NEXT:    212004:       c0 03 5f d6     ret

        .section .text.04, "ax", %progbits
        .space 64 * 1024 * 1024

        // Expect patch on pass 1
        .section .text.05, "ax", %progbits
        .balign 4096
        .space 4096 - 8
        .globl t3_ff8_str
        .type t3_ff8_str, %function
t3_ff8_str:
        adrp x0, dat
        ldr x1, [x1, #0]
        str x0, [x0, :got_lo12:dat]
        ret

// CHECK4: t3_ff8_str:
// CHECK4-NEXT:  4213ff8:       e0 00 02 b0     adrp    x0, #67227648
// CHECK4-NEXT:  4213ffc:       21 00 40 f9     ldr     x1, [x1]
// CHECK4-NEXT:  4214000:       04 00 80 14     b       #33554448
// CHECK4-NEXT:  4214004:       c0 03 5f d6     ret

        .section .text.06, "ax", %progbits
        .space 32 * 1024 * 1024

// CHECK5: __CortexA53843419_211000:
// CHECK5-NEXT:  6214008:       00 00 40 f9     ldr     x0, [x0]
// CHECK5-NEXT:  621400c:       fe f7 7f 16     b       #-100671496
// CHECK5: __CortexA53843419_4213000:
// CHECK5-NEXT:  6214010:       00 00 00 f9     str     x0, [x0]
// CHECK5-NEXT:  6214014:       fc ff 7f 17     b       #-33554448

        .section .text.07, "ax", %progbits
        .space (32 * 1024 * 1024) - 12300

        .section .text.08, "ax", %progbits
        .globl need_thunk_after_patch
        .type need_thunk_after_patch, %function
need_thunk_after_patch:
        ret

// CHECK6: need_thunk_after_patch:
// CHECK6-NEXT:  821100c:       c0 03 5f d6     ret

        // Will need a patch on pass 2
        .section .text.09, "ax", %progbits
        .space 4096 - 20
        .globl t3_ffc_ldr
        .type t3_ffc_ldr, %function
t3_ffc_ldr:
        adrp x0, dat
        ldr x1, [x1, #0]
        ldr x0, [x0, :got_lo12:dat]
        ret

// CHECK7: t3_ffc_ldr:
// CHECK7-NEXT:  8211ffc:       e0 00 00 f0     adrp    x0, #126976
// CHECK7-NEXT:  8212000:       21 00 40 f9     ldr     x1, [x1]
// CHECK7-NEXT:  8212004:       02 00 00 14     b       #8
// CHECK7-NEXT:  8212008:       c0 03 5f d6     ret
// CHECK7: __CortexA53843419_8212004:
// CHECK7-NEXT:  821200c:       00 00 40 f9     ldr     x0, [x0]
// CHECK7-NEXT:  8212010:       fe ff ff 17     b       #-8

        .section .data
        .globl dat
dat:    .quad 0
