// REQUIRES: x86
// RUN: llvm-ar rc %t.a
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld -shared %t.o %t.a -o /dev/null
