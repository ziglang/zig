# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-func-global-entry.s -o %t2.o
# RUN: ld.lld  -shared %t2.o  -o %t3.so
# RUN: ld.lld --no-toc-optimize %t.o %t3.so -o %t
# RUN: llvm-objdump -d -start-address=0x10010000 -stop-address=0x10010018 %t | FileCheck %s -check-prefix=CALLEE_DUMP
# RUN: llvm-objdump -d -start-address=0x12010020 -stop-address=0x12010084 %t | FileCheck %s -check-prefix=CALLER_DUMP
# RUN: llvm-objdump -D -start-address=0x12020008 -stop-address=0x12020010 %t | FileCheck %s -check-prefix=BRANCH_LT_LE
# RUN: llvm-readelf --sections %t | FileCheck %s -check-prefix=SECTIONS

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-func-global-entry.s -o %t2.o
# RUN: ld.lld  -shared %t2.o  -o %t3.so
# RUN: ld.lld --no-toc-optimize %t.o %t3.so -o %t
# RUN: llvm-objdump -d -start-address=0x10010000 -stop-address=0x10010018 %t | FileCheck %s -check-prefix=CALLEE_DUMP
# RUN: llvm-objdump -d -start-address=0x12010020 -stop-address=0x12010084 %t | FileCheck %s -check-prefix=CALLER_DUMP
# RUN: llvm-objdump -D -start-address=0x12020008 -stop-address=0x12020010 %t | FileCheck %s -check-prefix=BRANCH_LT_BE
# RUN: llvm-readelf --sections %t | FileCheck %s -check-prefix=SECTIONS

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
    bl foo_external_diff
    nop
    addi 1, 1, 32
    ld   0, 16(1)
    mtlr 0

    addis 4, 2, .LC1@toc@ha
    ld    4, .LC1@toc@l(4)
    lwz   4, 0(4)
    add   3, 3, 4
    blr


        .section        .toc,"aw",@progbits
.LC0:
       .tc a[TC],a
.LC1:
       .tc b[TC],b


        .data
        .type a,@object
        .globl a
        .p2align 2
a:
        .long 11
        .size a, 4

        .type b,@object
        .global b
        .p2align 2
b:
        .long 33
        .size b, 4

# Verify address of the callee
# CALLEE_DUMP: callee:
# CALLEE_DUMP:   10010000:  {{.*}}  addis 2, 12, 515
# CALLEE_DUMP:   10010004:  {{.*}}  addi 2, 2, -32544
# CALLEE_DUMP:   10010008:  {{.*}}  addis 4, 2, 0

# Verify the address of _start, and the call to the long-branch thunk.
# CALLER_DUMP: _start:
# CALLER_DUMP:   12010020:  {{.*}}  addis 2, 12, 3
# CALLER_DUMP:   12010038:  {{.*}}  bl .+56

# Verify the thunks contents: TOC-pointer + offset = .branch_lt[0]
#                             0x120380e8  + (-2 << 16 + 32552) = 0x12020008
# CALLER_DUMP: __long_branch_callee:
# CALLER_DUMP:   12010060:  {{.*}}  addis 12, 2, -2
# CALLER_DUMP:   12010064:  {{.*}}  ld 12, 32552(12)
# CALLER_DUMP:   12010068:  {{.*}}  mtctr 12
# CALLER_DUMP:   1201006c:  {{.*}}  bctr

# BRANCH_LT_LE:     Disassembly of section .branch_lt:
# BRANCH_LT_LE-NEXT:  .branch_lt:
# BRANCH_LT_LE-NEXT:  12020008:   08 00 01 10
# BRANCH_LT_LE-NEXT:  1202000c:   00 00 00 00

# BRANCH_LT_BE:     Disassembly of section .branch_lt:
# BRANCH_LT_BE-NEXT:  .branch_lt:
# BRANCH_LT_BE-NEXT:  12020008:   00 00 00 00
# BRANCH_LT_BE-NEXT:  1202000c:   10 01 00 08

#            [Nr] Name        Type            Address          Off     Size
# SECTIONS:  [ 9] .branch_lt  PROGBITS        0000000012020008 2020008 000008
# SECTIONS:  [11] .got        PROGBITS        00000000120300e0 20300e0 000008
