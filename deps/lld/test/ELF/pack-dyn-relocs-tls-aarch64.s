// REQUIRES: aarch64

// RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %s -o %t.o
// RUN: ld.lld -shared --pack-dyn-relocs=android %t.o -o %t.so
// RUN: llvm-readobj -relocations %t.so | FileCheck %s

// Bug 37841: Symbol::getVA must work on TLS symbols during the layout loop in
// finalizeSections.

    .global foo
foo:
    adrp    x0, :tlsdesc:tlsvar1
    ldr     x1, [x0, :tlsdesc_lo12:tlsvar1]
    add     x0, x0, :tlsdesc_lo12:tlsvar1
    .tlsdesccall tlsvar1

// Also test an atypical IE access from a shared object to a local TLS symbol.

    .global bar
bar:
    adrp    x0, :gottprel:tlsvar2
    ldr     x0, [x0, #:gottprel_lo12:tlsvar2]

    .section    .tdata,"awT",@progbits
    .space  0x1234
tlsvar1:
    .word   42
tlsvar2:
    .word   17

// CHECK:          Section ({{.+}}) .rela.dyn {
// CHECK-NEXT:     R_AARCH64_TLSDESC - 0x1234
// CHECK-NEXT:     R_AARCH64_TLS_TPREL64 - 0x1238
// CHECK-NEXT:     }
