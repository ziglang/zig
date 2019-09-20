// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv5-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 --shared 2>&1
// RUN: llvm-objdump --start-address=7340044 --stop-address=7340048 --triple=armv5-none-linux-gnueabi -d %t2 | FileCheck %s
// RUN: llvm-objdump --start-address=8388620 --stop-address=8388624 --triple=thumbv5-none-linux-gnueabi -d %t2 | FileCheck %s -check-prefix=CHECK-CALL
// RUN: llvm-objdump --start-address=13631520 --stop-address=13631584 --triple=armv5-none-linux-gnueabi -d %t2 | FileCheck %s -check-prefix=CHECK-PLT
// When we create a thunk to a PLT entry the relocation is redirected to the
// Thunk, changing its expression to a non-PLT equivalent. If the thunk
// becomes unusable we need to restore the relocation expression to the PLT
// form so that when we create a new thunk it targets the PLT.

// Test case that checks the case:
// - Thunk is created on pass 1 to a PLT entry for preemptible
// - Some other Thunk added in the same pass moves the thunk to
// preemptible out of range of its caller.
// - New Thunk is created on pass 2 to PLT entry for preemptible

        .globl preemptible
        .globl preemptible2
.section .text.01, "ax", %progbits
.balign 0x100000
        .thumb
        .globl needsplt
        .type needsplt, %function
needsplt:
        bl preemptible
        .section .text.02, "ax", %progbits
        .space (1024 * 1024)

        .section .text.03, "ax", %progbits
        .space (1024 * 1024)

        .section .text.04, "ax", %progbits
        .space (1024 * 1024)

        .section .text.05, "ax", %progbits
        .space (1024 * 1024)

        .section .text.06, "ax", %progbits
        .space (1024 * 1024)

        .section .text.07, "ax", %progbits
        .space (1024 * 1024)
// 0x70000c + 8 + 0x60002c = 0xd00040 = preemptible@plt
// CHECK: 0070000c __ARMV5PILongThunk_preemptible:
// CHECK-NEXT:   70000c:        0b 00 18 ea     b       #6291500

        .section .text.08, "ax", %progbits
        .space (1024 * 1024) - 4

        .section .text.10, "ax", %progbits
        .balign 2
        bl preemptible
        bl preemptible2
// 0x80000c + 4 - 100004 = 0x70000c = __ARMv5PILongThunk_preemptible
// CHECK-CALL: 80000c:   ff f6 fe ef     blx     #-1048580
        .balign 2
        .globl preemptible
        .type preemptible, %function
preemptible:
        bx lr
        .globl preemptible2
        .type preemptible2, %function
preemptible2:
        bx lr


        .section .text.11, "ax", %progbits
        .space (5 * 1024 * 1024)


// CHECK-PLT: Disassembly of section .plt:
// CHECK-PLT-EMPTY:
// CHECK-PLT-NEXT: 00d00020 $a:
// CHECK-PLT-NEXT:   d00020:    04 e0 2d e5     str     lr, [sp, #-4]!
// CHECK-PLT-NEXT:   d00024:    00 e6 8f e2     add     lr, pc, #0, #12
// CHECK-PLT-NEXT:   d00028:    01 ea 8e e2     add     lr, lr, #4096
// CHECK-PLT-NEXT:   d0002c:    dc ff be e5     ldr     pc, [lr, #4060]!
// CHECK-PLT: 00d00030 $d:
// CHECK-PLT-NEXT:   d00030:    d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK-PLT-NEXT:   d00034:    d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK-PLT-NEXT:   d00038:    d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK-PLT-NEXT:   d0003c:    d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK-PLT: 00d00040 $a:
// CHECK-PLT-NEXT:   d00040:    00 c6 8f e2     add     r12, pc, #0, #12
// CHECK-PLT-NEXT:   d00044:    01 ca 8c e2     add     r12, r12, #4096
// CHECK-PLT-NEXT:   d00048:    c4 ff bc e5     ldr     pc, [r12, #4036]!
// CHECK-PLT: 00d0004c $d:
// CHECK-PLT-NEXT:   d0004c:    d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK-PLT: 00d00050 $a:
// CHECK-PLT-NEXT:   d00050:    00 c6 8f e2     add     r12, pc, #0, #12
// CHECK-PLT-NEXT:   d00054:    01 ca 8c e2     add     r12, r12, #4096
// CHECK-PLT-NEXT:   d00058:    b8 ff bc e5     ldr     pc, [r12, #4024]!
// CHECK-PLT: 00d0005c $d:
// CHECK-PLT-NEXT:   d0005c:    d4 d4 d4 d4     .word   0xd4d4d4d4
