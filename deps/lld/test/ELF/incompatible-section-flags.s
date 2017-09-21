// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: not ld.lld -shared %t.o -o %t 2>&1 | FileCheck %s

// CHECK:      error: incompatible section flags for .foo
// CHECK-NEXT: >>> {{.*}}incompatible-section-flags.s.tmp.o:(.foo): 0x3
// CHECK-NEXT: >>> output section .foo: 0x403

// CHECK:      error: incompatible section flags for .bar
// CHECK-NEXT: >>> {{.*}}incompatible-section-flags.s.tmp.o:(.bar): 0x403
// CHECK-NEXT: >>> output section .bar: 0x3

.section .foo, "awT", @progbits, unique, 1
.quad 0

.section .foo, "aw", @progbits, unique, 2
.quad 0


.section .bar, "aw", @progbits, unique, 3
.quad 0

.section .bar, "awT", @progbits, unique, 4
.quad 0
