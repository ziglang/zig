# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-no-split-stack.s -o %t2.o
# RUN: ld.lld --defsym __morestack=0x10010000 %t1.o %t2.o -o %t
# RUN: llvm-objdump -d %t | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-no-split-stack.s -o %t2.o
# RUN: ld.lld --defsym __morestack=0x10010000 %t1.o %t2.o -o %t
# RUN: llvm-objdump -d %t | FileCheck %s

        .abiversion 2
        .section    ".text"


# A caller with a stack that is small enough that the addis instruction
# from the split-stack prologue is unneeded, and after the prologue adjustment
# the stack size still fits whithin 16 bits.
        .p2align    2
        .global caller_small_stack
        .type caller_small_stack, @function
caller_small_stack:
.Lcss_gep:
    addis 2, 12, .TOC.-.Lcss_gep@ha
    addi 2, 2, .TOC.-.Lcss_gep@l
    .localentry caller_small_stack, .-caller_small_stack
    ld 0, -0x7040(13)
    addi 12, 1, -32
    nop
    cmpld 7, 12, 0
    blt- 7, .Lcss_alloc_more
.Lcss_body:
    mflr 0
    std 0, 16(1)
    stdu 1, -32(1)
    bl nss_callee
    addi 1, 1, 32
    ld 0, 16(1)
    mtlr 0
    blr
.Lcss_alloc_more:
    mflr 0
    std 0, 16(1)
    bl __morestack
    ld 0, 16(1)
    mtlr 0
    blr
    b .Lcss_body
        .size caller_small_stack, .-caller_small_stack

# CHECK-LABEL: caller_small_stack
# CHECK:       ld 0, -28736(13)
# CHECK-NEXT:  addi 12, 1, -16416
# CHECK-NEXT:  nop
# CHECK-NEXT:  cmpld 7, 12, 0
# CHECK-NEXT:  bt-  28, .+36

# A caller that has a stack size that fits whithin 16 bits, but the adjusted
# stack size after prologue adjustment now overflows 16 bits needing both addis
# and addi instructions.
        .p2align    2
        .global caller_med_stack
        .type caller_med_stack, @function
caller_med_stack:
.Lcms_gep:
    addis 2, 12, .TOC.-.Lcms_gep@ha
    addi 12, 12, .TOC.-.Lcms_gep@l
    .localentry caller_med_stack, .-caller_med_stack
    ld 0, -0x7040(13)
    addi 12, 1, -32764
    nop
    cmpld 7, 12, 0
    blt- 7, .Lcms_alloc_more
.Lcms_body:
    mflr 0
    std 0, 16(1)
    stdu 1, -32764(1)
    bl nss_callee
    addi 1, 1, 32764
    ld 0, 16(1)
    mtlr 0
    blr
.Lcms_alloc_more:
    mflr 0
    std 0, 16(1)
    bl __morestack
    ld 0, 16(1)
    mtlr 0
    blr
    b .Lcms_body
        .size caller_med_stack, .-caller_med_stack

# A caller with a large enough stack frame that both the addis and
# addi instructions are used in the split-stack prologue.
        .p2align    2
        .global caller_large_stack
        .type caller_large_stack, @function
caller_large_stack:
.Lcls_gep:
    addis 2, 12, .TOC.-.Lcls_gep@ha
    addi 12, 12, .TOC.-.Lcls_gep@l
    .localentry caller_large_stack, .-caller_large_stack
    ld 0, -0x7040(13)
    addis 12, 1, -1
    addi  12, 12, -32
    cmpld 7, 12, 0
    blt- 7, .Lcls_alloc_more
.Lcls_body:
    mflr 0
    std 0, 16(1)
    lis 0, -1
    addi 0, 0, -32
    stdux 1, 0, 1
    bl nss_callee
    ld 1, 0(1)
    ld 0, 16(1)
    mtlr 0
    blr
.Lcls_alloc_more:
    mflr 0
    std 0, 16(1)
    bl __morestack
    ld 0, 16(1)
    mtlr 0
    blr
    b .Lcls_body
        .size caller_large_stack, .-caller_large_stack

# CHECK-LABEL: caller_large_stack
# CHECK:       ld 0, -28736(13)
# CHECK-NEXT:  addis 12, 1, -1
# CHECK-NEXT:  addi 12, 12, -16416
# CHECK-NEXT:  cmpld 7, 12, 0
# CHECK-NEXT:  bt-  28, .+44

# A caller with a stack size that is larger then 16 bits, but aligned such that
# the addi instruction is unneeded.
        .p2align    2
        .global caller_large_aligned_stack
        .type caller_large_aligned_stack, @function
caller_large_aligned_stack:
.Lclas_gep:
    addis 2, 12, .TOC.-.Lclas_gep@ha
    addi 12, 12, .TOC.-.Lclas_gep@l
    .localentry caller_large_aligned_stack, .-caller_large_aligned_stack
    ld 0, -0x7040(13)
    addis 12, 1, -2
    nop
    cmpld 7, 12, 0
    blt- 7, .Lclas_alloc_more
.Lclas_body:
    mflr 0
    std 0, 16(1)
    lis 0, -2
    stdux 1, 0, 1
    bl nss_callee
    ld 1, 0(1)
    ld 0, 16(1)
    mtlr 0
    blr
.Lclas_alloc_more:
    mflr 0
    std 0, 16(1)
    bl __morestack
    ld 0, 16(1)
    mtlr 0
    blr
    b .Lclas_body
        .size caller_large_aligned_stack, .-caller_large_aligned_stack

# CHECK-LABEL: caller_large_aligned_stack
# CHECK:       ld 0, -28736(13)
# CHECK-NEXT:  addis 12, 1, -2
# CHECK-NEXT:  addi 12, 12, -16384
# CHECK-NEXT:  cmpld 7, 12, 0
# CHECK-NEXT:  bt-  28, .+40

# main only calls split-stack functions or __morestack so
# there should be no adjustment of its split-stack prologue.
        .p2align    2
        .global main
	.type  main, @function
main:
.Lmain_gep:
    addis 2, 12,.TOC.-.Lmain_gep@ha
    addi 2, 2,.TOC.-.Lmain_gep@l
    .localentry	main,.-main
    ld 0, -0x7040(13)
    addi 12,1,-32
    nop
    cmpld 7, 12,0
    blt- 7, .Lmain_morestack
.Lmain_body:
    mflr 0
    std 0, 16(1)
    stdu 1, -32(1)
    bl caller_small_stack
    nop
    bl caller_med_stack
    nop
    bl caller_large_stack
    nop
    bl caller_large_aligned_stack
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
# CHECK-LABEL: main
# CHECK:       ld 0, -28736(13)
# CHECK-NEXT:  addi 12, 1, -32
# CHECK-NEXT:  nop
# CHECK-NEXT:  cmpld 7, 12, 0

    .section        .note.GNU-split-stack,"",@progbits
