// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o %t.o -o %t.so -shared
// RUN: llvm-readobj --dyn-symbols %t.so | FileCheck %s

// CHECK:      Name: foo
// CHECK-NEXT: Value: 0x123

.global foo
foo = 0x123

// RUN: echo ".global foo; foo = 0x124" >  %t2.s
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %t2.s -o %t2.o
// RUN: not ld.lld %t.o %t2.o -o %t.so -shared 2>&1 | FileCheck --check-prefix=DUP %s

// DUP:      duplicate symbol: foo
// DUP-NEXT: >>> defined in {{.*}}.o
// DUP-NEXT: >>> defined in {{.*}}2.o
