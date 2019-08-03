# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: llvm-readelf -r %t.o | FileCheck --check-prefix=InputRelocs %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/shared-ppc64.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so
#
# RUN: ld.lld  %t2.so %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=Dis %s
#
# RUN: ld.lld --no-toc-optimize %t2.so %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=NoOpt %s

# InputRelocs:  Relocation section '.rela.text'
# InputRelocs:   R_PPC64_TOC16_HA
# InputRelocs:   R_PPC64_TOC16_LO
# InputRelocs:   R_PPC64_TOC16_LO_DS


        .text
	.abiversion 2

        .global bytes
        .p2align        4
        .type   bytes,@function
bytes:
.Lbytes_gep:
        addis 2, 12, .TOC.-.Lbytes_gep@ha
        addi  2, 2,  .TOC.-.Lbytes_gep@l
.Lbytes_lep:
        .localentry     bytes, .Lbytes_lep-.Lbytes_gep
        addis 3, 2, byteLd@toc@ha
        lbz   3,    byteLd@toc@l(3)
        addis 4, 2, byteSt@toc@ha
        stb   3,    byteSt@toc@l(4)
        blr
# Dis-LABEL: bytes:
# Dis-NEXT:   addis
# Dis-NEXT:   addi
# Dis-NEXT:   nop
# Dis-NEXT:   lbz   3, 32624(2)
# Dis-NEXT:   nop
# Dis-NEXT:   stb   3, 32625(2)
# Dis-NEXT:   blr

# NoOpt-LABEL: bytes:
# NoOpt-NEXT:     addis
# NoOpt-NEXT:     addi
# NoOpt-NEXT:     addis 3, 2, 0
# NoOpt-NEXT:     lbz 3, 32624(3)
# NoOpt-NEXT:     addis 4, 2, 0
# NoOpt-NEXT:     stb 3, 32625(4)
# NoOpt-NEXT:     blr

        .global  halfs
        .p2align        4
        .type   halfs,@function
halfs:
.Lhalfs_gep:
        addis 2, 12, .TOC.-.Lhalfs_gep@ha
        addi  2, 2,  .TOC.-.Lhalfs_gep@l
.Lhalfs_lep:
        .localentry  halfs, .Lhalfs_lep-.Lhalfs_gep
        addis 3, 2, halfLd@toc@ha
        lhz   3,    halfLd@toc@l(3)
        addis 4, 2, halfLd@toc@ha
        lha   4,    halfLd@toc@l(4)
        addis 5, 2, halfSt@toc@ha
        sth   4,    halfSt@toc@l(5)
        blr
# Dis-LABEL: halfs:
# Dis-NEXT:   addis
# Dis-NEXT:   addi
# Dis-NEXT:   nop
# Dis-NEXT:   lhz   3, 32626(2)
# Dis-NEXT:   nop
# Dis-NEXT:   lha 4, 32626(2)
# Dis-NEXT:   nop
# Dis-NEXT:   sth 4, 32628(2)
# Dis-NEXT:   blr

# NoOpt-LABEL: halfs:
# NoOpt-NEXT:   addis
# NoOpt-NEXT:   addi
# NoOpt-NEXT:   addis 3, 2, 0
# NoOpt-NEXT:   lhz   3, 32626(3)
# NoOpt-NEXT:   addis 4, 2, 0
# NoOpt-NEXT:   lha 4, 32626(4)
# NoOpt-NEXT:   addis 5, 2, 0
# NoOpt-NEXT:   sth 4, 32628(5)
# NoOpt-NEXT:   blr


        .global words
        .p2align        4
        .type   words,@function
words:
.Lwords_gep:
       addis 2, 12, .TOC.-.Lwords_gep@ha
       addi  2, 2,  .TOC.-.Lwords_gep@l
.Lwords_lep:
       .localentry words, .Lwords_lep-.Lwords_gep
       addis 3, 2, wordLd@toc@ha
       lwz   3,    wordLd@toc@l(3)
       addis 4, 2, wordLd@toc@ha
       lwa   4,    wordLd@toc@l(4)
       addis 5, 2, wordSt@toc@ha
       stw   4,    wordSt@toc@l(5)
       blr
# Dis-LABEL: words
# Dis-NEXT:    addis
# Dis-NEXT:    addi
# Dis-NEXT:    nop
# Dis-NEXT:    lwz 3, 32632(2)
# Dis-NEXT:    nop
# Dis-NEXT:    lwa 4, 32632(2)
# Dis-NEXT:    nop
# Dis-NEXT:    stw 4, 32636(2)
# Dis-NEXT:    blr

# NoOpt-LABEL: words
# NoOpt-NEXT:    addis
# NoOpt-NEXT:    addi
# NoOpt-NEXT:    addis 3, 2, 0
# NoOpt-NEXT:    lwz 3, 32632(3)
# NoOpt-NEXT:    addis 4, 2, 0
# NoOpt-NEXT:    lwa 4, 32632(4)
# NoOpt-NEXT:    addis 5, 2, 0
# NoOpt-NEXT:    stw 4, 32636(5)
# NoOpt-NEXT:    blr

        .global doublewords
        .p2align        4
        .type   doublewords,@function
doublewords:
.Ldoublewords_gep:
       addis 2, 12, .TOC.-.Ldoublewords_gep@ha
       addi  2, 2,  .TOC.-.Ldoublewords_gep@l
.Ldoublewords_lep:
       .localentry doublewords, .Ldoublewords_lep-.Ldoublewords_gep
        addis 3, 2, dwordLd@toc@ha
        ld    3,    dwordLd@toc@l(3)
        addis 4, 2, dwordSt@toc@ha
        std   3,    dwordSt@toc@l(4)
        blr

# Dis-LABEL: doublewords
# Dis-NEXT:    addis
# Dis-NEXT:    addi
# Dis-NEXT:    nop
# Dis-NEXT:    ld 3, 32640(2)
# Dis-NEXT:    nop
# Dis-NEXT:    std 3, 32648(2)
# Dis-NEXT:    blr

# NoOpt-LABEL: doublewords
# NoOpt-NEXT:    addis
# NoOpt-NEXT:    addi
# NoOpt-NEXT:    addis 3, 2, 0
# NoOpt-NEXT:    ld 3, 32640(3)
# NoOpt-NEXT:    addis 4, 2, 0
# NoOpt-NEXT:    std 3, 32648(4)
# NoOpt-NEXT:    blr

       .global vec_dq
       .p2align 4
        .type vec_dq,@function
vec_dq:
.Lvec_dq_gep:
        addis 2, 12, .TOC.-.Lvec_dq_gep@ha
        addi  2,  2, .TOC.-.Lvec_dq_gep@l
.Lvec_dq_lep:
        .localentry  vec_dq, .Lvec_dq_lep-.Lvec_dq_gep
        addis 3, 2, vecLd@toc@ha
        lxv   3,    vecLd@toc@l(3)
        addis 3, 2, vecSt@toc@ha
        stxv  3,    vecSt@toc@l(3)
        blr

# Dis-LABEL: vec_dq:
# Dis-NEXT:    addis
# Dis-NEXT:    addi
# Dis-NEXT:    nop
# Dis-NEXT:    lxv 3, 32656(2)
# Dis-NEXT:    nop
# Dis-NEXT:    stxv 3, 32672(2)
# Dis-NEXT:    blr

# NoOpt-LABEL: vec_dq:
# NoOpt-NEXT:    addis
# NoOpt-NEXT:    addi
# NoOpt-NEXT:    addis 3, 2, 0
# NoOpt-NEXT:    lxv 3, 32656(3)
# NoOpt-NEXT:    addis 3, 2, 0
# NoOpt-NEXT:    stxv 3, 32672(3)
# NoOpt-NEXT:    blr

       .global vec_ds
       .p2align 4
        .type vec_ds,@function
vec_ds:
.Lvec_ds_gep:
        addis 2, 12, .TOC.-.Lvec_ds_gep@ha
        addi  2,  2, .TOC.-.Lvec_ds_gep@l
.Lvec_ds_lep:
        .localentry  vec_ds, .Lvec_dq_lep-.Lvec_dq_gep
        addis  3, 2, vecLd@toc@ha
        lxsd   3,    vecLd@toc@l(3)
        addis  3, 2, vecSt@toc@ha
        stxsd  3,    vecSt@toc@l(3)
        addis  3, 2, vecLd@toc@ha
        lxssp  3,    vecLd@toc@l(3)
        addis  3, 2, vecSt@toc@ha
        stxssp 3,    vecSt@toc@l(3)
        blr
# Dis-LABEL: vec_ds:
# Dis-NEXT:   addis
# Dis-NEXT:   addi
# Dis-NEXT:   nop
# Dis-NEXT:   lxsd 3, 32656(2)
# Dis-NEXT:   nop
# Dis-NEXT:   stxsd 3, 32672(2)
# Dis-NEXT:   nop
# Dis-NEXT:   lxssp 3, 32656(2)
# Dis-NEXT:   nop
# Dis-NEXT:   stxssp 3, 32672(2)
# Dis-NEXT:   blr

# NoOpt-LABEL: vec_ds:
# NoOpt-NEXT:   addis
# NoOpt-NEXT:   addi
# NoOpt-NEXT:   addis 3, 2, 0
# NoOpt-NEXT:   lxsd 3, 32656(3)
# NoOpt-NEXT:   addis 3, 2, 0
# NoOpt-NEXT:   stxsd 3, 32672(3)
# NoOpt-NEXT:   addis 3, 2, 0
# NoOpt-NEXT:   lxssp 3, 32656(3)
# NoOpt-NEXT:   addis 3, 2, 0
# NoOpt-NEXT:   stxssp 3, 32672(3)
# NoOpt-NEXT:   blr


       .global byteLd
       .lcomm  byteLd, 1, 1

       .global byteSt
       .lcomm  byteSt, 1, 1

       .global halfLd
       .lcomm  halfLd, 2, 2

       .global halfSt
       .lcomm  halfSt, 2, 2

       .global wordLd
       .lcomm  wordLd, 4, 4

       .global wordSt
       .lcomm  wordSt, 4, 4

       .global dwordLd
       .lcomm  dwordLd, 8, 8

       .global dwordSt
       .lcomm  dwordSt, 8, 8

       .global vecLd
       .lcomm  vecLd, 16, 16

       .global vecSt
       .lcomm  vecSt, 16, 16
