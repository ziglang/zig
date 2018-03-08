// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld --hash-style=sysv %t --shared -o %t2 2>&1
// RUN: llvm-readobj --relocations %t2 | FileCheck %s
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-EXTAB %s
// REQUIRES: arm

// Check that the relative R_ARM_PREL31 relocation can access a PLT entry
// for when the personality routine is referenced from a shared library.
// Also check that the R_ARM_NONE no-op relocation can be used in a shared
// library.
 .syntax unified
// Will produce an ARM.exidx entry with an R_ARM_NONE relocation to
// __aeabi_unwind_cpp_pr0
 .section .text.func1, "ax",%progbits
 .global func1
func1:
 .fnstart
 bx lr
 .fnend

// Will produce a R_ARM_PREL31 relocation with respect to the PLT entry of
// __gxx_personality_v0
 .section .text.func2, "ax",%progbits
 .global func2
func2:
 .fnstart
 bx lr
 .personality __gxx_personality_v0
 .handlerdata
 .long 0
 .section .text.func2
 .fnend

 .section .text.__aeabi_unwind_cpp_pr0, "ax", %progbits
 .global __aeabi_unwind_cpp_pr0
__aeabi_unwind_cpp_pr0:
 bx lr

// CHECK: Relocations [
// CHECK-NEXT:   Section (6) .rel.plt {
// CHECK-NEXT:     0x200C R_ARM_JUMP_SLOT __gxx_personality_v0

// CHECK-EXTAB: Contents of section .ARM.extab:
// 014c + 0ee4 = 0x1030 = __gxx_personality_v0(PLT)
// CHECK-EXTAB-NEXT:  014c e40e0000 b0b0b000 00000000
