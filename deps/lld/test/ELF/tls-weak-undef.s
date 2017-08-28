// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t --gc-sections

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux \
// RUN:   %p/Inputs/tls-in-archive.s -o %t1.o
// RUN: llvm-ar cru %t.a %t1.o
// RUN: ld.lld %t.o %t.a -o %t

// Check that lld doesn't crash because we don't reference
// the TLS phdr when it's not created.
        .globl  _start
_start:
        movq    foo@gottpoff(%rip), %rax
        .section        .tbss,"awT",@nobits
        .weak   foo
