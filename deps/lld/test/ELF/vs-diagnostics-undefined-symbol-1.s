// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: not ld.lld --vs-diagnostics %t1.o -o %tout 2>&1 \
// RUN:   | FileCheck -check-prefix=ERR -check-prefix=CHECK -DFILE=%t1.o %s
// RUN: ld.lld --vs-diagnostics --warn-unresolved-symbols %t1.o -o %tout 2>&1 \
// RUN:   | FileCheck -check-prefix=WARN -check-prefix=CHECK -DFILE=%t1.o %s

// ERR:        [[FILE]]: error: undefined symbol: foo
// WARN:       [[FILE]]: warning: undefined symbol: foo
// CHECK-NEXT: >>> referenced by {{.*}}1.o:(.text+0x{{.+}})

.global _start, foo
.text
_start:
  jmp foo