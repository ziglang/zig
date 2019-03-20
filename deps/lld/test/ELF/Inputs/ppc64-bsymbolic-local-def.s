        .abiversion 2
        .section ".text"

        .p2align 2
        .global def
        .type def, @function
def:
.Ldef_gep:
    addis 2, 12, .TOC.-.Ldef_gep@ha
    addi 2, 2, .TOC.-.Ldef_gep@l
.Ldef_lep:
    .localentry def, .-def
    li 3, 55
    blr
