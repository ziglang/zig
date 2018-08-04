// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: mkdir -p %t.dir
// RUN: rm -f %t.dir/liba.a
// RUN: llvm-ar rcs %t.dir/liba.a %t.o
// RUN: ld.lld -L%t.dir --whole-archive -la -o /dev/null -Map=- | FileCheck %s

.globl _start
_start:
    nop

// There was a use after free of an archive name.
// Valgrind/asan would detect it.
// CHECK:      liba.a(whole-archive-name.s.tmp.o):(.text)
// CHECK-NEXT:     _start
