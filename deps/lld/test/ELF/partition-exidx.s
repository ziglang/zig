// Test that exidx output sections are created correctly for each partition.

// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld %t.o -o %t -shared --gc-sections

// RUN: llvm-objcopy --extract-main-partition %t %t0
// RUN: llvm-objcopy --extract-partition=part1 %t %t1

// Change upper case to lower case so that we can match unwind info (which is dumped
// in upper case) against program headers (which are dumped in lower case).
// RUN: llvm-readelf -l --unwind %t0 | tr A-Z a-z | FileCheck %s
// RUN: llvm-readelf -l --unwind %t1 | tr A-Z a-z | FileCheck %s

// Each file should have one exidx section for its text section and one sentinel.
// CHECK:      sectionoffset: 0x[[EXIDX_OFFSET:.*]]
// CHECK-NEXT: entries [
// CHECK-NEXT:   entry {
// CHECK-NEXT:     functionaddress: 0x[[TEXT_ADDR:.*]]
// CHECK-NEXT:     model: cantunwind
// CHECK-NEXT:   }
// CHECK-NEXT:   entry {
// CHECK-NEXT:     functionaddress:
// CHECK-NEXT:     model: cantunwind
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// CHECK: load  {{[^ ]*}} 0x{{0*}}[[TEXT_ADDR]] {{.*}} r e
// CHECK: exidx 0x{{0*}}[[EXIDX_OFFSET]] {{.*}} 0x00010 0x00010 r

.section .llvm_sympart,"",%llvm_sympart
.asciz "part1"
.4byte p1

.section .text.p0,"ax",%progbits
.globl p0
p0:
.fnstart
bx lr
.cantunwind
.fnend

.section .text.p1,"ax",%progbits
.globl p1
p1:
.fnstart
bx lr
.cantunwind
.fnend
