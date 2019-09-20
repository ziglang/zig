// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi --arm-add-build-attributes %s -o %t
// RUN: ld.lld %t --no-merge-exidx-entries -o %t2
// RUN: llvm-objdump -s %t2 | FileCheck %s
// RUN: ld.lld %t -o %t3
// RUN: llvm-objdump -s %t3 | FileCheck %s -check-prefix=CHECK-MERGE

// The ARM.exidx section is a table of 8-byte entries of the form:
// | PREL31 Relocation to start of function | Unwinding information |
// The range of addresses covered by the table entry is terminated by the
// next table entry. This means that an executable section without a .ARM.exidx
// section does not terminate the range of addresses. To fix this the linker
// synthesises an EXIDX_CANTUNWIND entry for each section wihout a .ARM.exidx
// section.

        .syntax unified

        // Expect inline unwind instructions
        .section .text.01, "ax", %progbits
        .global f1
f1:
        .fnstart
        bx lr
        .save {r7, lr}
        .setfp r7, sp, #0
        .fnend

        // Expect no unwind information from assembler. The linker must
        // synthesise an EXIDX_CANTUNWIND entry to prevent an exception
        // thrown through f2 from matching against the unwind instructions
        // for f1.
        .section .text.02, "ax", %progbits
        .global f2
f2:
        bx lr


        // Expect 1 EXIDX_CANTUNWIND entry that can be merged into the linker
        // generated EXIDX_CANTUNWIND as if the assembler had generated it.
        .section .text.03, "ax",%progbits
        .global f3
f3:
        .fnstart
        bx lr
        .cantunwind
        .fnend

        // Dummy implementation of personality routines to satisfy reference
        // from exception tables, linker will generate EXIDX_CANTUNWIND.
        .section .text.__aeabi_unwind_cpp_pr0, "ax", %progbits
        .global __aeabi_unwind_cpp_pr0
__aeabi_unwind_cpp_pr0:
        bx lr

// f1, f2
// CHECK:      100d4 2c0f0000 08849780 280f0000 01000000
// f3, __aeabi_unwind_cpp_pr0
// CHECK-NEXT: 100e4 240f0000 01000000 200f0000 01000000
// sentinel
// CHECK-NEXT: 100f4 1c0f0000 01000000

// f1, (f2, f3, __aeabi_unwind_cpp_pr0)
// CHECK-MERGE:      100d4 2c0f0000 08849780 280f0000 01000000
// sentinel
// CHECK-MERGE-NEXT: 100e4 2c0f0000 01000000

