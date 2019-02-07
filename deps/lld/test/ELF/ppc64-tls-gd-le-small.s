# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: llvm-objdump -d -r %t.o | FileCheck --check-prefix=CHECK-INPUT %s
# RUN: ld.lld  --defsym __tls_get_addr=0x10001000 %t.o -o %t
# RUN: llvm-objdump -d %t | FileCheck --check-prefix=CHECK-DIS %s
# RUN: llvm-readelf -relocations %t | FileCheck --check-prefix=DYN-RELOCS %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: llvm-objdump -d -r %t.o | FileCheck --check-prefix=CHECK-INPUT %s
# RUN: ld.lld  --defsym __tls_get_addr=0x10001000 %t.o -o %t
# RUN: llvm-objdump -d %t | FileCheck --check-prefix=CHECK-DIS %s
# RUN: llvm-readelf -relocations %t | FileCheck --check-prefix=DYN-RELOCS %s

# Test checks the relaxation of a 'small' general-dynamic tls access into a
# local-exec tls access.

        .text
        .abiversion 2

        .global test
        .p2align    4
        .type test, @function

test:
.Lgep:
    addis 2, 12, .TOC.-.Lgep@ha
    addi  2, 2,  .TOC.-.Lgep@l
    .localentry test, .-test
    mflr 0
    std 0, 16(1)
    stdu 1, -32(1)
    addi 3, 2, a@got@tlsgd
    bl __tls_get_addr(a@tlsgd)
    nop
    lwz 3, 0(3)
    addi 1, 1, 32
    ld 0, 16(1)
    mtlr 0
    blr

        .type a, @object
        .section .tdata,"awT",@progbits
        .global a
        .p2align 2
a:
        .long 55
        .size a, 4

# CHECK-INPUT:       addi 3, 2, 0
# CHECK-INPUT-NEXT:  R_PPC64_GOT_TLSGD16  a
# CHECK-INPUT-NEXT:  bl .+0
# CHECK-INPUT-NEXT:  R_PPC64_TLSGD        a
# CHECK-INPUT-NEXT:  R_PPC64_REL24        __tls_get_addr

# CHECK-DIS:      addis 3, 13, 0
# CHECK-DIS-NEXT: nop
# CHECK-DIS-NEXT: addi  3, 3, -28672
# CHECK-DIS-NEXT: lwz 3, 0(3)

# DYN-RELOCS: There are no relocations in this file
