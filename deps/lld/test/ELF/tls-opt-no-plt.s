// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/tls-opt-gdie.s -o %t2.o
// RUN: ld.lld %t2.o -o %t2.so -shared
// RUN: ld.lld %t.o %t2.so -o %t.exe
// RUN: llvm-readobj -s %t.exe | FileCheck %s

// CHECK-NOT: .plt

        .global _start
_start:
        data16
        leaq    foo@TLSGD(%rip), %rdi
        data16
        data16
        rex64
        callq   __tls_get_addr@PLT

        leaq    bar@TLSLD(%rip), %rdi
        callq   __tls_get_addr@PLT
        leaq    bar@DTPOFF(%rax), %rax

        .type   bar,@object
        .section        .tdata,"awT",@progbits
        .align  8
bar:
        .long   42


        .type   foo,@object
        .section        .tdata,"awT",@progbits
        .globl  foo
        .align  8
foo:
        .long   42
