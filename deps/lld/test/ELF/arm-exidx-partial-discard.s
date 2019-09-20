// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple arm-gnu-linux-eabi -mcpu cortex-a7 -arm-add-build-attributes %s -o %t.o
// RUN: echo "SECTIONS { . = 0x10000; .text : { *(.text) } /DISCARD/ : { *(.exit.text) } }" > %t.script
// RUN: ld.lld -T %t.script %t.o -o %t.elf
// RUN: llvm-readobj -x .ARM.exidx --sections %t.elf | FileCheck %s

// CHECK-NOT: .exit.text
/// Expect 2 entries both CANTUNWIND as the .ARM.exidx.exit.text
// should have been removed.
// CHECK: Hex dump of section '.ARM.exidx':
// CHECK-NEXT: 0x00010000 10000000 01000000 10000000 01000000

/// The /DISCARD/ is evaluated after sections have been assigned to the
/// .ARM.exidx synthetic section. We must account for the /DISCARD/
 .section .exit.text, "ax", %progbits
 .globl foo
 .type foo, %function
foo:
 .fnstart
 bx lr
 .save {r7, lr}
 .setfp r7, sp, #0
 .fnend

 .text
 .globl _start
 .type _start, %function
_start:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .text.__aeabi_unwind_cpp_pr0, "ax", %progbits
 .global __aeabi_unwind_cpp_pr0
__aeabi_unwind_cpp_pr0:
 bx lr
