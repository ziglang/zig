// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/copy-rel-abs.s -o %t1.o
// RUN: ld.lld --hash-style=gnu -shared %t1.o -o %t1.so
// RUN: llvm-readelf --dyn-symbols %t1.so | FileCheck --check-prefix=SYMS %s

// The symbols have the same st_value, but one is ABS.
// SYMS: 0000000000001000 {{.*}}   4 bar
// SYMS: 0000000000001000 {{.*}}   4 foo
// SYMS: 0000000000001000 {{.*}} ABS zed

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
// RUN: ld.lld %t2.o %t1.so -o %t2
// RUN: llvm-readobj --dyn-symbols %t2 | FileCheck %s

// CHECK:      DynamicSymbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding:
// CHECK-NEXT:     Type:
// CHECK-NEXT:     Other:
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: foo
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding:
// CHECK-NEXT:     Type:
// CHECK-NEXT:     Other:
// CHECK-NEXT:     Section: .bss.rel.ro
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: bar
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding:
// CHECK-NEXT:     Type:
// CHECK-NEXT:     Other:
// CHECK-NEXT:     Section: .bss.rel.ro
// CHECK-NEXT:   }
// CHECK-NEXT: ]

.global _start
_start:
.quad foo
