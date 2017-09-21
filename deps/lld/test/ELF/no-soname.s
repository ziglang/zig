// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: mkdir -p %T/no-soname
// RUN: ld.lld %t.o -shared -o %T/no-soname/libfoo.so

// RUN: ld.lld %t.o %T/no-soname/libfoo.so -o %t
// RUN: llvm-readobj --dynamic-table %t | FileCheck %s

// CHECK:  0x0000000000000001 NEEDED               Shared library: [{{.*}}/no-soname/libfoo.so]
// CHECK-NOT: NEEDED

// RUN: ld.lld %t.o %T/no-soname/../no-soname/libfoo.so -o %t
// RUN: llvm-readobj --dynamic-table %t | FileCheck %s --check-prefix=CHECK2

// CHECK2:  0x0000000000000001 NEEDED               Shared library: [{{.*}}/no-soname/../no-soname/libfoo.so]
// CHECK2-NOT: NEEDED

// RUN: ld.lld %t.o -L%T/no-soname/../no-soname -lfoo -o %t
// RUN: llvm-readobj --dynamic-table %t | FileCheck %s --check-prefix=CHECK3

// CHECK3:  0x0000000000000001 NEEDED               Shared library: [libfoo.so]
// CHECK3-NOT: NEEDED

// RUN: ld.lld %t.o -shared -soname libbar.so -o %T/no-soname/libbar.so
// RUN: ld.lld %t.o %T/no-soname/libbar.so -o %t
// RUN: llvm-readobj --dynamic-table %t | FileCheck %s --check-prefix=CHECK4

// CHECK4:  0x0000000000000001 NEEDED               Shared library: [libbar.so]
// CHECK4-NOT: NEEDED

.global _start
_start:
