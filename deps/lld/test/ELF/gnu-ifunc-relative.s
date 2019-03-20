// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld --strip-all %t.o -o %t
// RUN: llvm-readobj -r %t | FileCheck %s
// RUN: ld.lld %t.o -o %t
// RUN: llvm-readobj -r -t %t | FileCheck %s --check-prefixes=CHECK,SYM

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

// SYM:      Name: foo
// SYM-NEXT: Value: 0x[[ADDR]]
// SYM-NEXT: Size: 0
// SYM-NEXT: Binding: Global
// SYM-NEXT: Type: GNU_IFunc
