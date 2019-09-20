// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld -shared --pack-dyn-relocs=android %t.o -o %t.so
// RUN: llvm-readobj -r %t.so | FileCheck %s

// Bug 37841: Symbol::getVA must work on TLS symbols during the layout loop in
// finalizeSections. This test uses an atypical IE access in a shared object to
// access a local TLS symbol, because a more typical access would avoid the
// bug.

    .globl  foo
foo:
    movq    tlsvar@GOTTPOFF(%rip), %rcx

    .section    .tdata,"awT",@progbits
    .space 0x1234
tlsvar:
    .word   42

// CHECK:          Section ({{.+}}) .rela.dyn {
// CHECK-NEXT:     R_X86_64_TPOFF64 - 0x1234
// CHECK-NEXT:     }
