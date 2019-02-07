# REQUIRES: ppc

# RUN: llvm-readelf -relocations --wide  %p/Inputs/ppc64le-quadword-ldst.o | FileCheck --check-prefix=QuadInputRelocs %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/shared-ppc64.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so

# RUN: ld.lld  %t2.so %p/Inputs/ppc64le-quadword-ldst.o -o %t
# RUN: llvm-objdump -D %t | FileCheck --check-prefix=Dis %s

# RUN: ld.lld --no-toc-optimize %t2.so %p/Inputs/ppc64le-quadword-ldst.o -o %t
# RUN: llvm-objdump -D %t | FileCheck --check-prefix=NoOpt %s

# QuadInputRelocs: Relocation section '.rela.text'
# QuadInputRelocs:  R_PPC64_TOC16_LO_DS    0000000000000000 quadLd
# QuadInputRelocs:  R_PPC64_TOC16_LO_DS    0000000000000010 quadSt

# The powerpc backend doesn't support the quadword load/store instructions yet.
# So they are tested by linking against an object file assembled with
# `as -mpower9 -o ppc64le-quadword-ldst.o in.s` and checking the encoding of
# the unknown instructions in the dissasembly. Source used as input:
#quads:
#.Lbegin_quads:
#.Lgep_quads:
#        addis 2, 12, .TOC.-.Lgep_quads@ha
#        addi  2, 2, .TOC.-.Lgep_quads@l
#.Llep_quads:
#.localentry quads, .Llep_quads-.Lgep_quads
#        addis 3, 2, quadLd@toc@ha
#        lq    4,    quadLd@toc@l(3)
#        addis 3, 2, quadSt@toc@ha
#        stq   4,    quadSt@toc@l(3)
#        blr
#
#        .p2align 4
#        .global quadLd
#        .lcomm  quadLd, 16
#
#        .global quadSt
#        .lcomm  quadSt, 16


# e0 82 7f 70 decodes to | 111000 | 00100 | 00010 | 16-bit imm |
#                        |   56   |   4   |   2   |   32624    |
# which is `lq r4, 32624(r2)`
# f8 82 7f 82 decodes to | 111110 | 00100 | 00010 | 14-bit imm | 10 |
#                        |   62   |   4   |   2   |    8160    | 2  |
# The immediate represents a word offset so this dissasembles to:
# `stq r4, 32640(r2)`
# Dis-LABEL: quads:
# Dis-NEXT:    addis
# Dis-NEXT:    addi
# Dis-NEXT:    nop
# Dis-NEXT:    70 7f 82 e0  <unknown>
# Dis-NEXT:    nop
# Dis-NEXT:    82 7f 82 f8  <unknown>
# Dis-NEXT:    blr

# e0 83 7f 70 decodes to | 111000 | 00100 | 00011 | 16-bit imm |
#                        |   56   |   4   |   3   |   32624    |
# `lq r4, 32624(r3)`
# f8 83 7f 82 decodes to | 111110 | 00100 | 00010 | 14-bit imm | 10 |
#                        |   62   |   4   |   2   |    8160    | 2  |
# `stq r4, 32640(r3)`
# NoOpt-LABEL: quads:
# NoOpt-NEXT:    addis
# NoOpt-NEXT:    addi
# NoOpt-NEXT:    addis 3, 2, 0
# NoOpt-NEXT:    70 7f 83 e0  <unknown>
# NoOpt-NEXT:    addis 3, 2, 0
# NoOpt-NEXT:    82 7f 83 f8  <unknown>
# NoOpt-NEXT:    blr

