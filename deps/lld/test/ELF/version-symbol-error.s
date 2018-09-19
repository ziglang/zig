// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: echo "V1 {};" > %t.script
// RUN: not ld.lld -shared -version-script=%t.script %t.o -o /dev/null 2>&1 \
// RUN:   | FileCheck %s

// CHECK: .o: symbol foo@V2 has undefined version V2

.globl foo@V2
.text
foo@V2:
  ret
