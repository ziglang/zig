# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/x86-64-tls-gd-got.s -o %t2.o
# RUN: ld.lld %t1.o %t2.o -o %t
# RUN: llvm-objdump -d %t | FileCheck %s

        .globl  _start
_start:
        .byte   0x66
        leaq    bar@tlsgd(%rip), %rdi
        .byte   0x66
        rex64
        call    *__tls_get_addr@GOTPCREL(%rip)
        ret

// CHECK:      _start:
// CHECK-NEXT:   movq    %fs:0, %rax
// CHECK-NEXT:   leaq    -4(%rax), %rax
// CHECK-NEXT:   retq
