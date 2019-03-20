// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-shared.s -o %t
// RUN: ld.lld %t --shared -o %t.so
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t2
// RUN: ld.lld %t2 %t.so -o %t3
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi -start-address=69632 -stop-address=69664 %t3 | FileCheck %s

// When we are dynamic linking, undefined weak references have a PLT entry so
// we must create a thunk for the branch to the PLT entry.

 .text
 .globl bar2
 .weak undefined_weak_we_expect_a_plt_entry_for
_start:
 .globl _start
 .type _start, %function
 b undefined_weak_we_expect_a_plt_entry_for
 bl bar2
// Create 32 Mb gap between the call to the weak reference and the PLT so that
// the b and bl need a range-extension thunk.
 .section .text.1, "ax", %progbits
 .space 32 * 1024 * 1024

// CHECK: Disassembly of section .text:
// CHECK-NEXT: _start:
// CHECK-NEXT:    11000:       00 00 00 ea     b       #0 <__ARMv7ABSLongThunk_undefined_weak_we_expect_a_plt_entry_for>
// CHECK-NEXT:    11004:       02 00 00 eb     bl      #8 <__ARMv7ABSLongThunk_bar2>
// CHECK: __ARMv7ABSLongThunk_undefined_weak_we_expect_a_plt_entry_for:
// CHECK-NEXT:    11008:        40 c0 01 e3     movw    r12, #4160
// CHECK-NEXT:    1100c:        01 c2 40 e3     movt    r12, #513
// CHECK-NEXT:    11010:        1c ff 2f e1     bx      r12
// CHECK: __ARMv7ABSLongThunk_bar2:
// CHECK-NEXT:    11014:        50 c0 01 e3     movw    r12, #4176
// CHECK-NEXT:    11018:        01 c2 40 e3     movt    r12, #513
// CHECK-NEXT:    1101c:        1c ff 2f e1     bx      r12
