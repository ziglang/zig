# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-bsymbolic-local-def.s  -o %t2.o
# RUN: ld.lld -Bsymbolic -shared %t1.o %t2.o -o %t
# RUN: llvm-objdump -d -r %t | FileCheck %s
# RUN: not ld.lld -shared %t1.o %t2.o -o %t 2>&1 | FileCheck --check-prefix=FAIL %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-bsymbolic-local-def.s  -o %t2.o
# RUN: ld.lld -Bsymbolic -shared %t1.o %t2.o -o %t
# RUN: llvm-objdump -d -r %t | FileCheck %s
# RUN: not ld.lld -shared %t1.o %t2.o -o %t 2>&1 | FileCheck --check-prefix=FAIL %s

# FAIL: call lacks nop, can't restore toc

# Test to document the toc-restore behavior with -Bsymbolic option. Since
# -Bsymbolic causes the call to bind to the internal defintion we know the
# caller and callee share the same TOC base. This means branching to the
# local entry point of the callee, and no need for a nop to follow the call
# (since there is no need to restore the TOC-pointer after the call).

        .abiversion 2
        .section ".text"

        .p2align 2
        .global caller
        .type caller, @function
caller:
.Lcaller_gep:
    addis 2, 12, .TOC.-.Lcaller_gep@ha
    addi  2, 2, .TOC.-.Lcaller_gep@l
.Lcaller_lep:
    .localentry caller, .-caller
    mflr 0
    std 0, -16(1)
    stdu 1, -32(1)
    bl def
    mr 31, 3
    bl not_defined
    nop
    add 3, 3, 31
    addi 1, 1, 32
    ld 0, -16(1)
    mtlr 0
    blr

# Note that the bl .+44 is a call to def's local entry, jumping past the first 2
# instructions. Branching to the global entry would corrupt the TOC pointer
# since the global entry requires that %r12 hold the address of the function
# being called.

# CHECK-LABEL: caller
# CHECK:         bl .+44
# CHECK-NEXT:    mr 31, 3
# CHECK-NEXT:    bl .+67108816
# CHECK-NEXT:    ld 2, 24(1)
# CHECK-NEXT:    add 3, 3, 31
# CHECK-NEXT:    addi 1, 1, 32
# CHECK-NEXT:    ld 0, -16(1)
# CHECK-NEXT:    mtlr 0
# CHECK-NEXT:    blr
# CHECK-EMPTY:
# CHECK-NEXT:  def:
# CHECK-NEXT:    addis 2, 12, 2
# CHECK-NEXT:    addi 2, 2, -32636
# CHECK-NEXT:    li 3, 55
# CHECK-NEXT:    blr
