// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: not ld.lld --vs-diagnostics %t1.o -o %tout 2>&1 \
// RUN:   | FileCheck -check-prefix=ERR -check-prefix=CHECK %s
// RUN: ld.lld --vs-diagnostics --warn-unresolved-symbols %t1.o -o %tout 2>&1 \
// RUN:   | FileCheck -check-prefix=WARN -check-prefix=CHECK %s

// ERR:        {{.*}}ld.lld{{.*}}: error: undefined symbol: foo
// WARN:       {{.*}}ld.lld{{.*}}: warning: undefined symbol: foo
// CHECK-NEXT: >>> referenced by undef2.s
// CHECK-NEXT: >>>               {{.*}}1.o:(.text+0x{{.+}})

.file "undef2.s"

.global _start, foo
.text
_start:
  jmp foo
