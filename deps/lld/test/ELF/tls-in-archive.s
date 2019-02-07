// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/tls-in-archive.s -o %t1.o
// RUN: rm -f %t.a
// RUN: llvm-ar cru %t.a %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
// RUN: ld.lld %t2.o %t.a -o /dev/null

        .globl  _start
_start:
        movq    foo@gottpoff(%rip), %rax
        .section        .tbss,"awT",@nobits
        .weak   foo
