// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/archive.s -o %ta.o
// RUN: rm -f %t.a
// RUN: llvm-ar rc %t.a %ta.o
// RUN: llvm-mc -filetype=obj -triple=i686-linux %s -o %tb.o
// RUN: not ld.lld %t.a %tb.o -o /dev/null 2>&1 | FileCheck %s

// We used to crash when
// * The first object seen by the symbol table is from an archive.
// * -m was not used.
// CHECK: .a({{.*}}a.o) is incompatible with {{.*}}b.o

