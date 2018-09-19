// REQUIRES: aarch64
// RUN: llvm-mc -triple=aarch64-linux-gnu -filetype=obj %s -o %t.o
// RUN: ld.lld %t.o -o %t
// RUN: llvm-objdump -d %t | FileCheck %s
// RUN: llvm-readelf --symbols %t | FileCheck -check-prefix CHECK-SYMS %s

        .text
        .globl _start
        .type _start, %function
_start:  mrs x8, TPIDR_EL0

        add x8, x8, :tprel_hi12:var0
        ldr q20, [x8, :tprel_lo12_nc:var0]

        add x8, x8, :tprel_hi12:var1
        ldr x0, [x8, :tprel_lo12_nc:var1]

        add x8, x8, :tprel_hi12:var2
        ldr w0, [x8, :tprel_lo12_nc:var2]

        add x8, x8, :tprel_hi12:var3
        ldrh w0, [x8, :tprel_lo12_nc:var3]

        add x8, x8, :tprel_hi12:var4
        ldrb w0, [x8, :tprel_lo12_nc:var4]

// CHECK: _start:
// CHECK-NEXT:    20000:       48 d0 3b d5     mrs     x8, TPIDR_EL0
// 0x0 + c10 = 0xc10       = tcb (16-bytes) + var0
// CHECK-NEXT:    20004:       08 01 40 91     add     x8, x8, #0, lsl #12
// CHECK-NEXT:    20008:       14 05 c3 3d     ldr     q20, [x8, #3088]
// 0x1000 + 0x820 = 0x1820 = tcb + var1
// CHECK-NEXT:    2000c:       08 05 40 91     add     x8, x8, #1, lsl #12
// CHECK-NEXT:    20010:       00 11 44 f9     ldr     x0, [x8, #2080]
// 0x2000 + 0x428 = 0x2428 = tcb + var2
// CHECK-NEXT:    20014:       08 09 40 91     add     x8, x8, #2, lsl #12
// CHECK-NEXT:    20018:       00 29 44 b9     ldr     w0, [x8, #1064]
// 0x3000 + 0x2c  = 0x302c = tcb + var3
// CHECK-NEXT:    2001c:       08 0d 40 91     add     x8, x8, #3, lsl #12
// CHECK-NEXT:    20020:       00 59 40 79     ldrh    w0, [x8, #44]
// 0x3000 + 0xc2e = 0x32ce = tcb + var4
// CHECK-NEXT:    20024:       08 0d 40 91     add     x8, x8, #3, lsl #12
// CHECK-NEXT:    20028:       00 b9 70 39     ldrb    w0, [x8, #3118]

// CHECK-SYMS:      0000000000000c00     0 TLS     GLOBAL DEFAULT    2 var0
// CHECK-SYMS-NEXT: 0000000000001810     4 TLS     GLOBAL DEFAULT    2 var1
// CHECK-SYMS-NEXT: 0000000000002418     2 TLS     GLOBAL DEFAULT    2 var2
// CHECK-SYMS-NEXT: 000000000000301c     1 TLS     GLOBAL DEFAULT    2 var3
// CHECK-SYMS-NEXT: 0000000000003c1e     0 TLS     GLOBAL DEFAULT    2 var4

        .globl var0
        .globl var1
        .globl var2
        .globl var3
        .globl var4
        .type var0,@object
        .type var1,@object
        .type var2,@object
        .type var3,@object

.section .tbss,"awT",@nobits
        .balign 16
        .space 1024 * 3
var0:
        .quad 0
        .quad 0
        .size var1, 16
        .space 1024 * 3
var1:
        .quad 0
        .size var1, 8
        .space 1024 * 3
var2:
        .word 0
        .size var1, 4

        .space 1024 * 3
var3:
        .hword 0
        .size var2, 2
        .space 1024 * 3
var4:
        .byte 0
        .size var3, 1
        .space 1024 * 3
