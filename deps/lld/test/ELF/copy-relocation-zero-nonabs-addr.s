// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/copy-relocation-zero-nonabs-addr.s -o %t1.o
// RUN: ld.lld -Ttext=0 -o %t2.so --script=%p/Inputs/copy-relocation-zero-nonabs-addr.script %t1.o -shared
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t3.o
// RUN: ld.lld %t2.so %t3.o -o %t4
// RUN: llvm-readobj --symbols %t2.so | FileCheck --check-prefix=CHECKSO %s
// RUN: llvm-readobj --symbols %t4 | FileCheck %s

.text
.globl _start
_start:
  movl $5, foo

// Make sure foo has st_value == 0.
// CHECKSO:      Name: foo
// CHECKSO-NEXT: Value: 0x0
// CHECKSO-NEXT: Size: 4
// CHECKSO-NEXT: Binding: Global
// CHECKSO-NEXT: Type: Object
// CHECKSO-NEXT: Other: 0
// CHECKSO-NEXT: Section: .text

// When foo has st_value == 0, it carries the section alignment.
// In this case, section alignment is 2^10, 0x202400 meets the requirement.
// CHECK:      Name: foo
// CHECK-NEXT: Value: 0x202400
// CHECK-NEXT: Size: 4
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type: Object
