// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t --no-merge-exidx-entries -o %t2 --gc-sections 2>&1
// RUN: llvm-objdump -d -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t2 | FileCheck -check-prefix=CHECK-EXIDX %s

// Test the behavior of .ARM.exidx sections under garbage collection
// A .ARM.exidx section is live if it has a relocation to a live executable
// section.
// A .ARM.exidx section may have a relocation to a .ARM.extab section, if the
// .ARM.exidx is live then the .ARM.extab section is live

 .syntax unified
 .section .text.func1, "ax",%progbits
 .global func1
func1:
 .fnstart
 bx lr
 .save {r7, lr}
 .setfp r7, sp, #0
 .fnend

 .section .text.unusedfunc1, "ax",%progbits
 .global unusedfunc1
unusedfunc1:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 // Unwinding instructions for .text2 too large for an inline entry ARM.exidx
 // entry. A separate .ARM.extab section is created to hold the unwind entries
 // The .ARM.exidx table entry has a reference to the .ARM.extab section.
 .section .text.func2, "ax",%progbits
 .global func2
func2:
 .fnstart
 bx lr
 .personality __gxx_personality_v0
 .handlerdata
 .section .text.func2
 .fnend

 // An unused function with a reference to a .ARM.extab section. Both should
 // be removed by gc.
 .section .text.unusedfunc2, "ax",%progbits
 .global unusedfunc2
unusedfunc2:
 .fnstart
 bx lr
 .personality __gxx_personality_v1
 .handlerdata
 .section .text.unusedfunc2
 .fnend

 // Dummy implementation of personality routines to satisfy reference from
 // exception tables
 .section .text.__gcc_personality_v0, "ax", %progbits
 .global __gxx_personality_v0
__gxx_personality_v0:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .text.__gcc_personality_v1, "ax", %progbits
 .global __gxx_personality_v1
__gxx_personality_v1:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .text.__aeabi_unwind_cpp_pr0, "ax", %progbits
 .global __aeabi_unwind_cpp_pr0
__aeabi_unwind_cpp_pr0:
 .fnstart
 bx lr
 .cantunwind
 .fnend

// Entry point for GC
 .text
 .global _start
_start:
 bl func1
 bl func2
 bx lr

// GC should have only removed unusedfunc1 and unusedfunc2 the personality
// routines are kept alive by references from live .ARM.exidx and .ARM.extab
// sections
// CHECK: Disassembly of section .text:
// CHECK-NEXT: _start:
// CHECK-NEXT:   11000:       01 00 00 eb     bl      #4 <func1>
// CHECK-NEXT:   11004:       01 00 00 eb     bl      #4 <func2>
// CHECK-NEXT:   11008:       1e ff 2f e1     bx      lr
// CHECK: func1:
// CHECK-NEXT:   1100c:       1e ff 2f e1     bx      lr
// CHECK: func2:
// CHECK-NEXT:   11010:       1e ff 2f e1     bx      lr
// CHECK: __gxx_personality_v0:
// CHECK-NEXT:   11014:       1e ff 2f e1     bx      lr
// CHECK: __aeabi_unwind_cpp_pr0:
// CHECK-NEXT:   11018:       1e ff 2f e1     bx      lr

// GC should have removed table entries for unusedfunc1, unusedfunc2
// and __gxx_personality_v1
// CHECK-NOT: unusedfunc1
// CHECK-NOT: unusedfunc2
// CHECK-NOT: __gxx_personality_v1

// CHECK-EXIDX: Contents of section .ARM.exidx:
// 100d4 + f38 = 1100c = func1
// 100dc + f34 = 11010 = func2 (100e0 + 1c = 100fc = .ARM.extab)
// CHECK-EXIDX-NEXT: 100d4 380f0000 08849780 340f0000 1c000000
// 100e4 + f30 = 11014 = __gxx_personality_v0
// 100ec + f2c = 11018 = __aeabi_unwind_cpp_pr0
// CHECK-EXIDX-NEXT: 100e4 300f0000 01000000 2c0f0000 01000000
// 100f4 + f28 = 1101c = __aeabi_unwind_cpp_pr0 + sizeof(__aeabi_unwind_cpp_pr0)
// CHECK-EXIDX-NEXT: 100f4 280f0000 01000000
// CHECK-EXIDX-NEXT: Contents of section .ARM.extab:
// 100fc + f18 = 11014 = __gxx_personality_v0
// CHECK-EXIDX-NEXT: 100fc 180f0000 b0b0b000
