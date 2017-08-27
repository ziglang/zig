// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld -static %t.o -o %tout
// RUN: llvm-readobj -r -t %tout | FileCheck %s
// REQUIRES: x86

.type foo STT_GNU_IFUNC
.globl foo
foo:
 ret

.globl _start
_start:
 call foo

// CHECK:      Section ({{.*}}) .rela.plt {
// CHECK-NEXT:   R_X86_64_IRELATIVE - 0x[[ADDR:.*]]
// CHECK-NEXT: }

// CHECK:      Name: foo
// CHECK-NEXT: Value: 0x[[ADDR]]
// CHECK-NEXT: Size: 0
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type: GNU_IFunc
