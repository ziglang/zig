// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld %t -o %t2
// RUN: llvm-readobj --symbols %t2 | FileCheck %s

// CHECK:      Symbol {
// CHECK:        Name: bar_sym
// CHECK-NEXT:   Value:
// CHECK-NEXT:   Size:
// CHECK-NEXT:   Binding:
// CHECK-NEXT:   Type:
// CHECK-NEXT:   Other:
// CHECK-NEXT:   Section: bar
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: foo_sym
// CHECK-NEXT:   Value:
// CHECK-NEXT:   Size:
// CHECK-NEXT:   Binding:
// CHECK-NEXT:   Type:
// CHECK-NEXT:   Other:
// CHECK-NEXT:   Section: foo
// CHECK-NEXT: }

.section foo
.global foo_sym
foo_sym:

.section bar, "a"
.global bar_sym
bar_sym:

.global _start
_start:
