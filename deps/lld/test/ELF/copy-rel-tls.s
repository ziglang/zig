// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/copy-rel-tls.s -o %t1.o
// RUN: ld.lld %t1.o -shared -soname t1.so -o %t1.so
// RUN: ld.lld %t.o %t1.so -o %t
// RUN: llvm-nm %t1.so | FileCheck %s
// RUN: llvm-nm %t | FileCheck --check-prefix=TLS %s
// foo and tfoo have the same st_value but we should not copy tfoo.
// CHECK: 2000 B foo
// CHECK: 2000 B tfoo
// TLS-NOT: tfoo

.global _start
_start:
  leaq foo, %rax
