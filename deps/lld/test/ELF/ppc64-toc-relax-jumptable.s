# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -S %t | FileCheck --check-prefixes=SECTIONS %s
# RUN: llvm-readelf -x .toc %t | FileCheck --check-prefixes=HEX-LE %s
# RUN: llvm-objdump -d %t | FileCheck --check-prefixes=CHECK %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -S %t | FileCheck --check-prefixes=SECTIONS %s
# RUN: llvm-readelf -x .toc %t | FileCheck --check-prefixes=HEX-BE %s
# RUN: llvm-objdump -d %t | FileCheck --check-prefixes=CHECK %s

# .LJT is a local symbol (non-preemptable).
# Test we can perform the toc-indirect to toc-relative relaxation.

# SECTIONS: .rodata PROGBITS 00000000100001c8

# HEX-LE:      section '.toc':
# HEX-LE-NEXT: 10020008 c8010010 00000000

# HEX-BE:      section '.toc':
# HEX-BE-NEXT: 10020008 00000000 100001c8

# CHECK-LABEL: _start
# CHECK:       clrldi  3, 3, 62
# CHECK-NEXT:  addis 4, 2, -2
# CHECK-NEXT:  addi  4, 4, -32312
# CHECK-NEXT:  sldi  3, 3, 2

    .text
    .global _start
    .type _start, @function
_start:
.Lstart_gep:
    addis 2, 12, .TOC.-.Lstart_gep@ha
    addi  2,  2, .TOC.-.Lstart_gep@l
.Lstart_lep:
    .localentry _start, .Lstart_lep-.Lstart_gep
    rldicl 3, 3, 0, 62
    addis 4, 2, .LJTI_TE@toc@ha
    ld    4, .LJTI_TE@toc@l(4)
    sldi  3, 3, 2
    lwax  3, 3, 4
    add   3, 3, 4
    mtctr 3
    bctr

.LBB1:
    li 3, 0
    blr
.LBB2:
    li 3, 10
    blr
.LBB3:
    li 3, 55
    blr
.LBB4:
    li 3, 255
    blr

    .section        .rodata,"a",@progbits
    .p2align        2
.LJT:
    .long   .LBB1-.LJT
    .long   .LBB2-.LJT
    .long   .LBB3-.LJT
    .long   .LBB4-.LJT

.section        .toc,"aw",@progbits
# TOC entry for the jumptable address.
.LJTI_TE:
    .tc .LJT[TC],.LJT
