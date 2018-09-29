// REQUIRES: ppc
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readobj -t -r -dyn-symbols %t.so | FileCheck %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readobj -t -r -dyn-symbols %t.so | FileCheck %s

// Test that we create R_PPC64_RELATIVE relocations but don't put any
// symbols in the dynamic symbol table.

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     0x[[FOO_ADDR:.*]] R_PPC64_RELATIVE - 0x[[FOO_ADDR]]
// CHECK-NEXT:     0x[[BAR_ADDR:.*]] R_PPC64_RELATIVE - 0x[[BAR_ADDR]]
// CHECK-NEXT:     0x10010 R_PPC64_RELATIVE - 0x10009
// CHECK-NEXT:     0x{{.*}} R_PPC64_RELATIVE - 0x[[ZED_ADDR:.*]]
// CHECK-NEXT:     0x{{.*}} R_PPC64_RELATIVE - 0x[[FOO_ADDR]]
// CHECK-NEXT:     0x10028 R_PPC64_ADDR64 external 0x0
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
// CHECK-NEXT:     Name: @
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: external@
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
