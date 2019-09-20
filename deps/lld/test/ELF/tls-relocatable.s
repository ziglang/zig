// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -r -o %tr.o
// RUN: ld.lld %tr.o -shared -o %t1
// RUN: llvm-readobj --symbols %t1 | FileCheck %s

// CHECK:       Symbol {
// CHECK:         Name: tls0
// CHECK-NEXT:    Value: 0x0
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Global
// CHECK-NEXT:    Type: TLS
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .tdata
// CHECK-NEXT:  }

.type tls0,@object
.section .tdata,"awT",@progbits
.globl tls0
tls0:
 .long 0
