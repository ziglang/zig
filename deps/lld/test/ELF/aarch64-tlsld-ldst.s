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
// CHECK-NEXT:    210000:       48 d0 3b d5     mrs     x8, TPIDR_EL0
// 0x0 + c40 = 0xc40       = tcb (64-bytes) + var0
// CHECK-NEXT:    210004:       08 01 40 91     add x8, x8, #0, lsl #12
// CHECK-NEXT:    210008:       14 11 c3 3d     ldr q20, [x8, #3136]
// 0x1000 + 0x850 = 0x1850 = tcb + var1
// CHECK-NEXT:    21000c:       08 05 40 91     add x8, x8, #1, lsl #12
// CHECK-NEXT:    210010:       00 29 44 f9     ldr x0, [x8, #2128]
// 0x2000 + 0x458 = 0x2458 = tcb + var2
// CHECK-NEXT:    210014:       08 09 40 91     add x8, x8, #2, lsl #12
// CHECK-NEXT:    210018:       00 59 44 b9     ldr w0, [x8, #1112]
// 0x3000 + 0x5c  = 0x305c = tcb + var3
// CHECK-NEXT:    21001c:       08 0d 40 91     add x8, x8, #3, lsl #12
// CHECK-NEXT:    210020:       00 b9 40 79     ldrh  w0, [x8, #92]
// 0x3000 + 0xc5e = 0x3c5e = tcb + var4
// CHECK-NEXT:    210024:       08 0d 40 91     add x8, x8, #3, lsl #12
// CHECK-NEXT:    210028:       00 79 71 39     ldrb  w0, [x8, #3166]

// CHECK-SYMS:      0000000000000c00    16 TLS     GLOBAL DEFAULT    2 var0
// CHECK-SYMS-NEXT: 0000000000001810     8 TLS     GLOBAL DEFAULT    2 var1
// CHECK-SYMS-NEXT: 0000000000002418     4 TLS     GLOBAL DEFAULT    2 var2
// CHECK-SYMS-NEXT: 000000000000301c     2 TLS     GLOBAL DEFAULT    2 var3
// CHECK-SYMS-NEXT: 0000000000003c1e     1 TLS     GLOBAL DEFAULT    2 var4

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
        .balign 64
        .space 1024 * 3
var0:
        .quad 0
        .quad 0
        .size var0, 16
        .space 1024 * 3
var1:
        .quad 0
        .size var1, 8
        .space 1024 * 3
var2:
        .word 0
        .size var2, 4

        .space 1024 * 3
var3:
        .hword 0
        .size var3, 2
        .space 1024 * 3
var4:
        .byte 0
        .size var4, 1
        .space 1024 * 3
