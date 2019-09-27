    .text
    .global getA
    .type getA,@function
getA:
.LgepA:
    addis 2, 12, .TOC.-.LgepA@ha
    addi 2, 2, .TOC.-.LgepA@l
.LlepA:
    .localentry getA, .LlepA-.LgepA
    ld 3, .LC0@toc(2)
    lwa 3, 0(3)
    blr

    .global getB
    .type getB,@function
getB:
.LgepB:
    addis 2, 12, .TOC.-.LgepB@ha
    addi 2, 2, .TOC.-.LgepB@l
.LlepB:
    .localentry getB, .LlepB-.LgepB
    ld 3, .LC1@toc(2)
    lwa 3, 0(3)
    blr

    .section .toc,"aw",@progbits
.LC0:
    .tc a[TC],a
.LConst1:
    .quad 0xa
.LC1:
    .tc b[TC],b
.Lconst2:
    .quad 0xaabbccddeeff

    .type b,@object
    .data
    .global b
b:
    .long 22
    .size b, 4
