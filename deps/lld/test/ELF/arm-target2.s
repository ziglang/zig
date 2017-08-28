// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld %t.o -o %t 2>&1
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t | FileCheck %s
// RUN: ld.lld %t.o --target2=got-rel -o %t2 2>&1
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s
// RUN: ld.lld %t.o --target2=abs -o %t3 2>&1
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t3 | FileCheck -check-prefix=CHECK-ABS %s
// RUN: ld.lld %t.o --target2=rel -o %t4 2>&1
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t4 | FileCheck -check-prefix=CHECK-REL %s
// REQUIRES: arm

// The R_ARM_TARGET2 is present in .ARM.extab sections. It can be handled as
// either R_ARM_ABS32, R_ARM_REL32 or R_ARM_GOT_PREL. For ARM linux the default
// is R_ARM_GOT_PREL. The other two options are primarily used for bare-metal,
// they can be selected with the --target2=abs or --target2=rel option.
 .syntax unified
 .text
 .globl _start
 .align 2
_start:
 .type function, %function
 .fnstart
 bx lr
 .personality   __gxx_personality_v0
 .handlerdata
 .word  _ZTIi(TARGET2)
 .text
 .fnend
 .global __gxx_personality_v0
 .type function, %function
__gxx_personality_v0:
 bx lr

 .rodata
_ZTIi:  .word 0

// CHECK: Contents of section .ARM.extab:
// 1011c + 1ee4 = 12000 = .got
// CHECK-NEXT:  10114 f00e0000 b0b0b000 e41e0000

// CHECK-ABS: Contents of section .ARM.extab:
// 100f0 = .rodata
// CHECK-ABS-NEXT: 100d4 300f0000 b0b0b000 f0000100

// CHECK-REL: Contents of section .ARM.extab:
// 100dc + c = 100e8 = .rodata
// CHECK-REL-NEXT: 100d4 300f0000 b0b0b000 14000000

// CHECK: Contents of section .rodata:
// CHECK-NEXT: 10130 00000000

// CHECK-ABS: Contents of section .rodata:
// CHECK-ABS-NEXT: 100f0 00000000

// CHECK-REL: Contents of section .rodata:
// CHECK-REL-NEXT: 100f0 00000000

// CHECK: Contents of section .got:
// 10130 = _ZTIi
// CHECK-NEXT: 12000 30010100
