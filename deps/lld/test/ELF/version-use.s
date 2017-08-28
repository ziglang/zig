// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t.o %p/Inputs/version-use.so -o %t.so -shared -z defs
// RUN: llvm-readobj -s %t.so | FileCheck %s


        call    bar@PLT

// CHECK-NOT: SHT_GNU_versym
