// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %p/Inputs/shared2.s -o %t3.o
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %p/Inputs/shared3.s -o %t4.o
// RUN: ld.lld -shared %t2.o -soname shared1 -o %t2.so
// RUN: ld.lld -shared %t3.o -soname shared2 -o %t3.so
// RUN: ld.lld -shared %t4.o -soname shared3 -o %t4.so

/// Check if --as-needed actually works.

// RUN: ld.lld %t.o %t2.so %t3.so %t4.so -o %t2
// RUN: llvm-readobj -dynamic-table %t2 | FileCheck %s

// RUN: ld.lld --as-needed %t.o %t2.so %t3.so %t4.so -o %t2
// RUN: llvm-readobj -dynamic-table %t2 | FileCheck -check-prefix=CHECK2 %s

// Test with the .o last
// RUN: ld.lld --as-needed %t2.so %t3.so %t4.so %t.o -o %t2
// RUN: llvm-readobj -dynamic-table %t2 | FileCheck -check-prefix=CHECK2 %s

// RUN: ld.lld --as-needed %t.o %t2.so --no-as-needed %t3.so %t4.so -o %t2
// RUN: llvm-readobj -dynamic-table %t2 | FileCheck %s

/// GROUP command is the same as listing the files on the command line.

// RUN: echo "GROUP(\"%t2.so\" \"%t3.so\" \"%t4.so\")" > %t.script
// RUN: ld.lld %t.o %t.script -o %t2
// RUN: llvm-readobj -dynamic-table %t2 | FileCheck %s

// RUN: echo "GROUP(AS_NEEDED(\"%t2.so\" \"%t3.so\" \"%t4.so\"))" > %t.script
// RUN: ld.lld %t.o %t.script -o %t2
// RUN: llvm-readobj -dynamic-table %t2 | FileCheck -check-prefix=CHECK2 %s

// CHECK: NEEDED Shared library: [shared1]
// CHECK: NEEDED Shared library: [shared2]
// CHECK: NEEDED Shared library: [shared3]

// CHECK2:     NEEDED Shared library: [shared1]
// CHECK2-NOT: NEEDED Shared library: [shared2]
// CHECK2-NOT: NEEDED Shared library: [shared3]

.global _start
_start:
.data
.long bar
.long zed
.weak baz
  call baz
