// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readobj -t -r -dyn-symbols %t.so | FileCheck %s

// Test that we create R_X86_64_RELATIVE relocations but don't put any
// symbols in the dynamic symbol table.

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     0x[[FOO_ADDR:.*]] R_X86_64_RELATIVE - 0x[[FOO_ADDR]]
// CHECK-NEXT:     0x[[BAR_ADDR:.*]] R_X86_64_RELATIVE - 0x[[BAR_ADDR]]
// CHECK-NEXT:     0x1010 R_X86_64_RELATIVE - 0x1009
// CHECK-NEXT:     0x{{.*}} R_X86_64_RELATIVE - 0x[[ZED_ADDR:.*]]
// CHECK-NEXT:     0x{{.*}} R_X86_64_RELATIVE - 0x[[FOO_ADDR]]
// CHECK-NEXT:     0x1028 R_X86_64_64 external 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// CHECK:      Symbols [
// CHECK:        Name: foo
// CHECK-NEXT:   Value: 0x[[FOO_ADDR]]
// CHECK:        Name: bar
// CHECK-NEXT:   Value: 0x[[BAR_ADDR]]
// CHECK:        Name: zed
// CHECK-NEXT:   Value: 0x[[ZED_ADDR]]
// CHECK:      ]

// CHECK:      DynamicSymbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: external
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT: ]

        .data
foo:
        .quad foo

        .hidden bar
        .global bar
bar:
        .quad bar
        .quad bar + 1

        .hidden zed
        .comm zed,1
        .quad zed

        .section abc,"aw"
        .quad foo

        .quad external

// This doesn't need a relocation.
        callq localfunc@PLT
localfunc:
