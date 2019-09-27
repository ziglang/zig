// REQUIRES: arm
// RUN: llvm-mc -filetype=obj --arm-add-build-attributes -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld --emit-relocs %t -o %t2
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s
// RUN: llvm-readelf --relocs %t2 | FileCheck -check-prefix=CHECK-RELOCS %s

// LLD does not support --emit-relocs for .ARM.exidx sections as the relocations
// from synthetic table entries won't be represented. Given the known use cases
// of --emit-relocs, relocating kernels, and binary analysis, the former doesn't
// use exceptions and the latter can derive the relocations from the table if
// they need them.
 .syntax unified
 // Will produce an ARM.exidx entry with inline unwinding instructions
 .section .text.func1, "ax",%progbits
 .global func1
func1:
 .fnstart
 bx lr
 .save {r7, lr}
 .setfp r7, sp, #0
 .fnend

 .syntax unified
 .section .text.func2, "ax",%progbits
// A function with the same inline unwinding instructions, expect merge.
 .global func2
func2:
 .fnstart
 bx lr
 .save {r7, lr}
 .setfp r7, sp, #0
 .fnend

 .section .text.25, "ax", %progbits
 .global func25
func25:
        .fnstart
        bx lr
        .cantunwind
        .fnend

 .section .text.26, "ax", %progbits
 .global func26
func26:
        .fnstart
        bx lr
        .cantunwind
        .fnend

 .syntax unified
 .section .text.func3, "ax",%progbits
// A function with the same inline unwinding instructions, expect merge.
 .global func3
func3:
 .fnstart
 bx lr
 .save {r7, lr}
 .setfp r7, sp, #0
 .fnend

 .section .text.__aeabi_unwind_cpp_pr0, "ax", %progbits
 .global __aeabi_unwind_cpp_pr0
__aeabi_unwind_cpp_pr0:
 bx lr

// CHECK: Contents of section .ARM.exidx:
// CHECK-NEXT:  100d4 2c0f0000 08849780 2c0f0000 01000000
// CHECK-NEXT:  100e4 2c0f0000 08849780 280f0000 01000000
// CHECK-NEXT:  100f4 240f0000 01000000

// CHECK-RELOCS-NOT: Relocation section '.rel.ARM.exidx'
