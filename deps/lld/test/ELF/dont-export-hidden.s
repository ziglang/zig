// RUN: llvm-mc %p/Inputs/shared.s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: llvm-mc %s -o %t2.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: ld.lld %t2.o %t.so -o %t.exe
// RUN: llvm-readobj --dyn-symbols %t.exe | FileCheck %s

        .global _start
_start:
        .global bar
        .hidden bar
bar:

        .global bar2
bar2:

        .global foo
foo:

// CHECK:      DynamicSymbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: @
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: bar2
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT: ]

