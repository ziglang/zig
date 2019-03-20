# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d %t | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d %t | FileCheck %s

        .global test
        .p2align        4
        .type   test,@function
test:
.Lgep:
        addis 2, 12, .TOC.-.Lgep@ha
        addi  2, 2,  .TOC.-.Lgep@l
.Llep:
        .localentry test, .Llep-.Lgep
        addis 3, 2, qword@toc@ha
        lxv   3, qword@toc@l(3)
        addis 3, 2, qword@toc@ha
        stxv  3, qword@toc@l(3)
        blr

       .comm qword, 16, 16

# Verify that we don't overwrite any of the extended opcode bits on a DQ form
# instruction.
# CHECK-LABEL: test
# CHECK:         lxv 3, -32768(3)
# CHECK:         stxv 3, -32768(3)
