    .text

    .global set
    .type set,@function
set:
.Lgep:
    addis 2, 12, .TOC.-.Lgep@ha
    addi 2, 2, .TOC.-.Lgep@l
.Llep:
    .localentry	set, .Llep-.Lgep
    addis 5, 2, .LC0@toc@ha
    addis 6, 2, .LC1@toc@ha
    ld 5, .LC0@toc@l(5)
    ld 6, .LC1@toc@l(6)
    stw 3, 0(5)
    stw 4, 0(6)
    blr

    .section .toc,"aw",@progbits
.LC0:
    .tc c[TC],c
.LC1:
    .tc d[TC],d
