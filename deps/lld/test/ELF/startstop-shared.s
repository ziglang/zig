// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -r --symbols %t.so | FileCheck  %s

        .data
        .quad __start_foo
        .section foo,"aw"

        .hidden __start_bar
        .quad __start_bar
        .section bar,"a"

// CHECK:      Relocations [
// CHECK-NEXT:   Section {{.*}} .rela.dyn {
// CHECK-NEXT:     R_X86_64_RELATIVE
// CHECK-NEXT:     R_X86_64_RELATIVE
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// Test that we are able to hide the symbol.
// By default the symbol is protected.

// CHECK:      Name: __start_bar
// CHECK-NEXT: Value:
// CHECK-NEXT: Size:
// CHECK-NEXT: Binding: Local
// CHECK-NEXT: Type: None
// CHECK-NEXT: Other [
// CHECK-NEXT:   STV_HIDDEN
// CHECK-NEXT: ]

// CHECK:      Name: __start_foo
// CHECK-NEXT: Value:
// CHECK-NEXT: Size:
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type: None
// CHECK-NEXT: Other [
// CHECK-NEXT:   STV_PROTECTED
// CHECK-NEXT: ]
