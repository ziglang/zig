# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-no-split-stack.s -o %t2.o

# RUN: ld.lld %t1.o %t2.o -o %t --defsym __morestack=0x10010000 -split-stack-adjust-size 32768
# RUN: llvm-objdump -d %t | FileCheck %s
# RUN: ld.lld %t1.o %t2.o -o %t --defsym __morestack=0x10010000 -split-stack-adjust-size 4096
# RUN: llvm-objdump -d %t | FileCheck %s -check-prefix=SMALL
# RUN: ld.lld %t1.o %t2.o -o %t --defsym __morestack=0x10010000 -split-stack-adjust-size 0
# RUN: llvm-objdump -d %t | FileCheck %s -check-prefix=ZERO
# RUN: not ld.lld %t1.o %t2.o -o %t -split-stack-adjust-size -1 2>&1 | FileCheck %s -check-prefix=ERR
# ERR: error: --split-stack-adjust-size: size must be >= 0

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-no-split-stack.s -o %t2.o

# RUN: ld.lld %t1.o %t2.o -o %t --defsym __morestack=0x10010000 -split-stack-adjust-size 32768
# RUN: llvm-objdump -d %t | FileCheck %s
# RUN: ld.lld %t1.o %t2.o -o %t --defsym __morestack=0x10010000 -split-stack-adjust-size 4096
# RUN: llvm-objdump -d %t | FileCheck %s -check-prefix=SMALL
# RUN: ld.lld %t1.o %t2.o -o %t --defsym __morestack=0x10010000 -split-stack-adjust-size 0
# RUN: llvm-objdump -d %t | FileCheck %s -check-prefix=ZERO
        .p2align    2
        .global caller
        .type caller, @function
caller:
.Lcaller_gep:
    addis 2, 12, .TOC.-.Lcaller_gep@ha
    addi 2, 2, .TOC.-.Lcaller_gep@l
    .localentry caller, .-caller
    ld 0, -0x7040(13)
    addi 12, 1, -32
    nop
    cmpld 7, 12, 0
    blt- 7, .Lcaller_alloc_more
.Lcaller_body:
    mflr 0
    std 0, 16(1)
    stdu 1, -32(1)
    bl nss_callee
    addi 1, 1, 32
    ld 0, 16(1)
    mtlr 0
    blr
.Lcaller_alloc_more:
    mflr 0
    std 0, 16(1)
    bl __morestack
    ld 0, 16(1)
    mtlr 0
    blr
    b .Lcaller_body
        .size caller, .-caller

# CHECK-LABEL: caller
# CHECK:      ld 0, -28736(13)
# CHECK-NEXT: addis 12, 1, -1
# CHECK-NEXT: addi 12, 12, 32736
# CHECK-NEXT: cmpld 7, 12, 0
# CHECK-NEXT: bt- 28, .+36

# SMALL-LABEL: caller
# SMALL:      ld 0, -28736(13)
# SMALL-NEXT: addi 12, 1, -4128
# SMALL-NEXT: nop
# SMALL-NEXT: cmpld 7, 12, 0
# SMALL-NEXT: bt- 28, .+36

# ZERO-LABEL: caller
# ZERO:      ld 0, -28736(13)
# ZERO-NEXT: addi 12, 1, -32
# ZERO-NEXT: nop
# ZERO-NEXT: cmpld 7, 12, 0
# ZERO-NEXT: bt- 28, .+36
        .p2align    2
        .global main
	.type  main, @function
main:
.Lmain_gep:
    addis 2,12,.TOC.-.Lmain_gep@ha
    addi 2,2,.TOC.-.Lmain_gep@l
    .localentry	main,.-main
    ld 0,-0x7040(13)
    addi 12,1,-32
    nop
    cmpld 7,12,0
    blt- 7, .Lmain_morestack
.Lmain_body:
    mflr 0
    std 0, 16(1)
    stdu 1, -32(1)
    bl caller
    addi 1, 1, 32
    ld 0, 16(1)
    mtlr 0
    blr
.Lmain_morestack:
    mflr 0
    std 0, 16(1)
    bl __morestack
    ld 0, 16(1)
    mtlr 0
    blr
    b .Lmain_body
    .size main,.-main

        .section        .note.GNU-split-stack,"",@progbits
