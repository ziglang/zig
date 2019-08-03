# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld --no-toc-optimize %t.o -o %t
# RUN: llvm-nm %t | FileCheck --check-prefix=NM %s
# RUN: llvm-readelf -x .branch_lt %t | FileCheck %s -check-prefix=BRANCH-LE
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: ld.lld --no-toc-optimize %t.o -o %t
# RUN: llvm-nm %t | FileCheck --check-prefix=NM %s
# RUN: llvm-readelf -x .branch_lt %t | FileCheck %s -check-prefix=BRANCH-BE
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

        .text
        .abiversion 2
        .protected callee
        .globl callee
        .p2align 4
        .type callee,@function
callee:
.Lfunc_gep0:
    addis 2, 12, .TOC.-.Lfunc_gep0@ha
    addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
    .localentry callee, .Lfunc_lep0-.Lfunc_gep0
    addis 4, 2, .LC0@toc@ha
    ld    4, .LC0@toc@l(4)
    lwz   3, 0(4)
    blr

        .space 0x2000000

        .protected _start
        .global _start
        .p2align 4
        .type _start,@function
_start:
.Lfunc_begin1:
.Lfunc_gep1:
    addis 2, 12, .TOC.-.Lfunc_gep1@ha
    addi 2, 2, .TOC.-.Lfunc_gep1@l
.Lfunc_lep1:
    .localentry	_start, .Lfunc_lep1-.Lfunc_gep1
    mflr 0
    std  0, 16(1)
    stdu 1, -32(1)
    bl callee
    bl callee
    addi 1, 1, 32
    ld   0, 16(1)
    mtlr 0

        .section        .toc,"aw",@progbits
.LC0:
       .tc a[TC],a


        .data
        .type a,@object
        .globl a
        .p2align 2
a:
        .long 11
        .size a, 4

# NM: 0000000012028000 d .TOC.

# Without --toc-optimize, compute the address of .toc[0] first. .toc[0] stores
# the address of a.
# .TOC. - callee = 0x12030000 - 0x10010000 = (514<<16) - 32768
# CHECK: callee:
# CHECK:   10010000:       addis 2, 12, 514
# CHECK:   10010004:       addi 2, 2, -32768
# CHECK:   10010008:       addis 4, 2, 0

# __long_branch_callee - . = 0x12010050 - 0x12010034 = 20
# __long_branch_callee is not a PLT call stub. Calling it does not need TOC
# restore, so it doesn't have to be followed by a nop.
# CHECK: _start:
# CHECK:   12010034:       bl .+20
# CHECK:   12010038:       bl .+16

# BRANCH-LE:     section '.branch_lt':
# BRANCH-LE-NEXT: 0x12030008 08000110 00000000
# BRANCH-BE:     section '.branch_lt':
# BRANCH-BE-NEXT: 0x12030008 00000000 10010008

# .branch_lt - .TOC. = 0x12030008 - 0x12028000 = (1<<16) - 32760
# CHECK:     __long_branch_callee:
# CHECK-NEXT: 12010048:       addis 12, 2, 1
# CHECK-NEXT:                 ld 12, -32760(12)
# CHECK-NEXT:                 mtctr 12
# CHECK-NEXT:                 bctr
