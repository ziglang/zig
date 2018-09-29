// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/protected-shared.s -o %t2.o
// RUN: ld.lld %t2.o -o %t2.so -shared
// RUN: not ld.lld %t.o %t2.so -o %t 2>&1 | FileCheck %s

// CHECK: cannot preempt symbol: bar
// CHECK: >>> defined in {{.*}}.so
// CHECK: >>> referenced by {{.*}}.o:(.text+0x1)

// CHECK: error: symbol 'zed' has no type
// CHECK-NEXT: >>> defined in {{.*}}.so
// CHECK-NEXT: >>> referenced by {{.*}}.o:(.text+0x6)

// RUN: not ld.lld --noinhibit-exec %t.o %t2.so -o %t 2>&1 | FileCheck %s --check-prefix=NOINHIBIT
// NOINHIBIT: warning: symbol 'zed' has no type
// NOINHIBIT-NEXT: >>> defined in {{.*}}.so
// NOINHIBIT-NEXT: >>> referenced by {{.*}}.o:(.text+0x6)

.global _start
_start:
.byte 0xe8
.long bar - .
.byte 0xe8
.long zed - .
