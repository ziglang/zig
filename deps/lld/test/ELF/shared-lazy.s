// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: rm -f %t1.a
// RUN: llvm-ar rc %t1.a %t1.o
// RUN: ld.lld %t1.o -o %t1.so -shared
// RUN: echo ".global foo" > %t2.s
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %t2.s -o %t2.o
// RUN: ld.lld %t1.a %t1.so %t2.o -o %t.so -shared
// RUN: llvm-readelf --dyn-symbols %t.so | FileCheck %s

// Test that 'foo' from %t1.so is used and we don't fetch a member
// from the archive.

// CHECK: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT UND foo

.global foo
foo:
