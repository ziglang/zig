# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: not ld.lld %t.o -o %t 2>&1 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: not ld.lld %t.o -o %t 2>&1 | FileCheck %s

# CHECK: improper alignment for relocation R_PPC64_TOC16_LO_DS: 0x8001 is not aligned to 4 bytes

        .global test
        .p2align        4
        .type   test,@function
test:
.Lgep:
        addis 2, 12, .TOC.-.Lgep@ha
        addi  2, 2,  .TOC.-.Lgep@l
.Llep:
        .localentry test, .Llep-.Lgep
        addis 3, 2, word@toc@ha
        lwa   3, word@toc@l(3)
        blr

       .comm pad, 1, 1
       .comm word, 4, 1

