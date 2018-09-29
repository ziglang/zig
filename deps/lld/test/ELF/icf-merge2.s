# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t --icf=all
# RUN: llvm-objdump -d %t | FileCheck %s

# Test that we don't merge these.
# CHECK: leaq
# CHECK: leaq

        .section .merge1, "aM", @progbits, 8
.Lfoo:
        .quad 42

        .section .merge2, "aM", @progbits, 4
.Lbar:
        .long 41

        .section .text.foo, "ax", @progbits
        leaq    .Lfoo(%rip), %rax

        .section .text.bar, "ax", @progbits
        leaq    .Lbar(%rip), %rax
