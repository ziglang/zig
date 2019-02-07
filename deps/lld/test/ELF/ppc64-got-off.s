# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld -shared --no-toc-optimize %t.o -o %t
# RUN: llvm-objdump -d %t | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared --no-toc-optimize %t.o -o %t
# RUN: llvm-objdump -d %t | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t
# RUN: llvm-objdump -d %t | FileCheck --check-prefix=OPT %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t
# RUN: llvm-objdump -d %t | FileCheck --check-prefix=OPT %s

        .abiversion 2
        .section ".text"

        .p2align 2
        .global func
        .type func, @function
func:
.Lfunc_gep:
        addis 2, 12, .TOC.-.Lfunc_gep@ha
        addi 2, 2, .TOC.-.Lfunc_gep@l
.Lfunc_lep:
        .localentry func, .-func
        addis 3, 2, a@got@ha
        ld    3, a@got@l(3)
        ld    4, a@got(2)
        lis   5, a@got@h
        ori   5, 5, a@got@l
        li    6, 0
        ori   6, 6, a@got
        blr

# CHECK-LABEL: func
# CHECK:         addis 3, 2, 0
# CHECK-NEXT:    ld 3, -32760(3)
# CHECK-NEXT:    ld 4, -32760(2)
# CHECK-NEXT:    lis 5, -1
# CHECK-NEXT:    ori 5, 5, 32776
# CHECK-NEXT:    li  6, 0
# CHECK-NEXT:    ori 6, 6, 32776

# OPT-LABEL: func
# OPT:         nop
# OPT-NEXT:    ld 3, -32760(2)
# OPT-NEXT:    ld 4, -32760(2)
# OPT-NEXT:    lis 5, -1
# OPT-NEXT:    ori 5, 5, 32776
# OPT-NEXT:    li  6, 0
# OPT-NEXT:    ori 6, 6, 32776

# Since the got entry for a is .got[1] and the TOC base points to
# .got + 0x8000, the offset for a@got is -0x7FF8 --> -32760

        .section ".data"
        .global a
        .type a, @object
        .size a, 4
        .p2align 2
a:
        .long 0x1000
