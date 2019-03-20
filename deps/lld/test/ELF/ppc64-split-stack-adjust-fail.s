# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-no-split-stack.s -o %t2.o

# RUN: not ld.lld --defsym __morestack=0x10010000 %t1.o %t2.o -o %t 2>&1 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-no-split-stack.s -o %t2.o

# RUN: not ld.lld --defsym __morestack=0x10010000 %t1.o %t2.o -o %t 2>&1 | FileCheck %s

# CHECK: error: {{.*}}.o:(.text): wrong_regs (with -fsplit-stack) calls nss_callee (without -fsplit-stack), but couldn't adjust its prologue

        .abiversion 2
        .section    ".text"

        .p2align 2
        .global wrong_regs
        .type wrong_regs, @function

wrong_regs:
.Lwr_gep:
    addis 2, 12, .TOC.-.Lwr_gep@ha
    addi 2, 2, .TOC.-.Lwr_gep@l
    .localentry wrong_regs, .-wrong_regs
    ld 0, -0x7040(13)
    addis 5, 2, -1
    addi  5, 5, -32
    addi 12, 1, -32
    nop
    cmpld 7, 12, 0
    blt- 7, .Lwr_alloc_more
.Lwr_body:
    mflr 0
    std 0, 16(1)
    stdu 1, -32(1)
    bl nss_callee
    addi 1, 1, 32
    ld 0, 16(1)
    mtlr 0
    blr
.Lwr_alloc_more:
    mflr 0
    std 0, 16(1)
    bl __morestack
    ld 0, 16(1)
    mtlr 0
    blr
    b .Lwr_body
        .size wrong_regs, .-wrong_regs

        .section        .note.GNU-split-stack,"",@progbits
