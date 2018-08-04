// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readelf -relocations --wide %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: llvm-readelf -relocations --wide %t.so | FileCheck --check-prefix=OutputRelocs %s
// RUN: llvm-objdump -D %t.so | FileCheck --check-prefix=Dis %s
// RUN: llvm-objdump -D %t.so | FileCheck --check-prefix=GotDisLE %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readelf -relocations --wide %t.o | FileCheck --check-prefix=InputRelocs %s
// RUN: llvm-readelf -relocations --wide %t.so | FileCheck --check-prefix=OutputRelocs %s
// RUN: llvm-objdump -D %t.so | FileCheck --check-prefix=Dis %s
// RUN: llvm-objdump -D %t.so | FileCheck --check-prefix=GotDisBE %s

        .text
        .abiversion 2
        .globl  test
        .p2align        4
        .type   test,@function
test:
.Lfunc_gep0:
        addis 2, 12, .TOC.-.Lfunc_gep0@ha
        addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
        .localentry     test, .Lfunc_lep0-.Lfunc_gep0
        mflr 0
        std 0, 16(1)
        stdu 1, -32(1)
        addis 3, 2, i@got@tlsld@ha
        addi 3, 3, i@got@tlsld@l
        bl __tls_get_addr(i@tlsld)
        nop
        addi 4, 3, i@dtprel
        lwa 4, i@dtprel(3)
        ld 0, 16(1)
        mtlr 0
        blr

        .globl test_64
        .p2align        4
        .type    test_64,@function

        .globl test_adjusted
        .p2align        4
        .type    test_adjusted,@function
test_adjusted:
.Lfunc_gep1:
        addis 2, 12, .TOC.-.Lfunc_gep1@ha
        addi 2, 2, .TOC.-.Lfunc_gep1@l
.Lfunc_lep1:
        .localentry     test_adjusted, .Lfunc_lep1-.Lfunc_gep1
        mflr 0
        std 0, 16(1)
        stdu 1, -32(1)
        addis 3, 2, k@got@tlsld@ha
        addi 3, 3, k@got@tlsld@l
        bl __tls_get_addr(k@tlsld)
        nop
        lis 4, k@dtprel@highesta
        ori 4, 4, k@dtprel@highera
        lis 5, k@dtprel@ha
        addi 5, 5, k@dtprel@l
        sldi 4, 4, 32
        or   4, 4, 5
        add  3, 3, 4
        addi 1, 1, 32
        ld 0, 16(1)
        mtlr 0
        blr

        .globl test_not_adjusted
        .p2align      4
        .type test_not_adjusted,@function
test_not_adjusted:
.Lfunc_gep2:
        addis 2, 12, .TOC.-.Lfunc_gep2@ha
        addi 2, 2, .TOC.-.Lfunc_gep2@l
.Lfunc_lep2:
        .localentry     test_not_adjusted, .Lfunc_lep2-.Lfunc_gep2
        mflr 0
        std 0, 16(1)
        stdu 1, -32(1)
        addis 3, 2, i@got@tlsld@ha
        addi 3, 3, i@got@tlsld@l
        bl __tls_get_addr(k@tlsld)
        nop
        lis 4, k@dtprel@highest
        ori 4, 4, k@dtprel@higher
        sldi 4, 4, 32
        oris  4, 4, k@dtprel@h
        ori   4, 4, k@dtprel@l
        add 3, 3, 4
        addi 1, 1, 32
        ld 0, 16(1)
        mtlr 0
        blr

        .globl test_got_dtprel
        .p2align 4
        .type test_got_dtprel,@function
test_got_dtprel:
         addis 3, 2, i@got@dtprel@ha
         ld 3, i@got@dtprel@l(3)
         addis 3, 2, i@got@dtprel@h
         addi 3, 2, i@got@dtprel

        .section        .debug_addr,"",@progbits
        .quad   i@dtprel+32768

        .type   i,@object
        .section        .tdata,"awT",@progbits
        .space 1024
        .p2align        2
i:
        .long   55
        .size   i, 4

        .space 1024 * 1024 * 4
        .type k,@object
        .p2align 2
k:
       .long 128
       .size k,4

// Verify the input has all the remaining DTPREL based relocations we want to
// test.
// InputRelocs: Relocation section '.rela.text'
// InputRelocs: R_PPC64_DTPREL16          {{[0-9a-f]+}} i + 0
// InputRelocs: R_PPC64_DTPREL16_DS       {{[0-9a-f]+}} i + 0
// InputRelocs: R_PPC64_DTPREL16_HIGHESTA {{[0-9a-f]+}} k + 0
// InputRelocs: R_PPC64_DTPREL16_HIGHERA  {{[0-9a-f]+}} k + 0
// InputRelocs: R_PPC64_DTPREL16_HA       {{[0-9a-f]+}} k + 0
// InputRelocs: R_PPC64_DTPREL16_LO       {{[0-9a-f]+}} k + 0
// InputRelocs: R_PPC64_DTPREL16_HIGHEST  {{[0-9a-f]+}} k + 0
// InputRelocs: R_PPC64_DTPREL16_HIGHER   {{[0-9a-f]+}} k + 0
// InputRelocs: R_PPC64_DTPREL16_HI       {{[0-9a-f]+}} k + 0
// InputRelocs: R_PPC64_DTPREL16_LO       {{[0-9a-f]+}} k + 0
// InputRelocs: R_PPC64_GOT_DTPREL16_HA    {{[0-9a-f]+}} i + 0
// InputRelocs: R_PPC64_GOT_DTPREL16_LO_DS {{[0-9a-f]+}} i + 0
// InputRelocs: R_PPC64_GOT_DTPREL16_HI    {{[0-9a-f]+}} i + 0
// InputRelocs: R_PPC64_GOT_DTPREL16_DS    {{[0-9a-f]+}} i + 0
// InputRelocs: Relocation section '.rela.debug_addr'
// InputRelocs: R_PPC64_DTPREL64          {{[0-9a-f]+}} i + 8000

// Expect a single dynamic relocation in the '.rela.dyn section for the module id.
// OutputRelocs:      Relocation section '.rela.dyn' at offset 0x{{[0-9a-f]+}} contains 1 entries:
// OutputRelocs-NEXT: Offset Info Type Symbol's Value Symbol's Name + Addend
// OutputRelocs-NEXT: R_PPC64_DTPMOD64


// i@dtprel  --> (1024 - 0x8000) = -31744
// Dis: test:
// Dis:    addi 4, 3, -31744
// Dis:    lwa 4, -31744(3)

// #k@dtprel(1024 + 4 + 1024 * 1024 * 4) = 0x400404

// #highesta(k@dtprel) --> ((0x400404 - 0x8000 + 0x8000) >> 48) & 0xffff = 0
// #highera(k@dtprel)  --> ((0x400404 - 0x8000 + 0x8000) >> 32) & 0xffff = 0
// #ha(k@dtprel)       --> ((0x400404 - 0x8000 + 0x8000) >> 16) & 0xffff = 64
// #lo(k@dtprel)       --> ((0x400404 - 0x8000) & 0xffff = -31740
// Dis:  test_adjusted:
// Dis:     lis 4, 0
// Dis:     ori 4, 4, 0
// Dis:     lis 5, 64
// Dis:     addi 5, 5, -31740

// #highest(k@dtprel) --> ((0x400404 - 0x8000) >> 48) & 0xffff = 0
// #higher(k@dtprel)  --> ((0x400404 - 0x8000) >> 32) & 0xffff = 0
// #hi(k@dtprel)      --> ((0x400404 - 0x8000) >> 16) & 0xffff = 63
// #lo(k@dtprel)      --> ((0x400404 - 0x8000) & 0xffff = 33796
// Dis:  test_not_adjusted:
// Dis:    lis 4, 0
// Dis:    ori 4, 4, 0
// Dis:    oris 4, 4, 63
// Dis:    ori 4, 4, 33796

// Check for GOT entry for i. There should be a got entry which holds the offset
// of i relative to the dynamic thread pointer.
// i@dtprel ->  (1024 - 0x8000) = 0xffff8400
// GotDisBE: Disassembly of section .got:
// GotDisBE: 4204f8: 00 00 00 00
// GotDisBE: 4204fc: 00 42 84 f8
// GotDisBE: 420510: ff ff ff ff
// GotDisBE: 420514: ff ff 84 00

// GotDisLE: Disassembly of section .got:
// GotDisLE: 4204f8: f8 84 42 00
// GotDisLE: 420510: 00 84 ff ff
// GotDisLE: 420514: ff ff ff ff

// Check that we have the correct offset to the got entry for i@got@dtprel
// The got entry for i is 0x420510, and the TOC pointer is 0x4284f8.
// #ha(i@got@dtprel) --> ((0x420510 - 0x4284f8 + 0x8000) >> 16) & 0xffff = 0
// #lo(i@got@dtprel) --> (0x420510 - 0x4284f8) & 0xffff = -32744
// #hi(i@got@dtprel) --> ((0x420510 - 0x4284f8) >> 16) & 0xffff = -1
// i@got@dtprel --> 0x420510 - 0x4284f8 = -32744
// Dis: test_got_dtprel:
// Dis:    addis 3, 2, 0
// Dis:    ld 3, -32744(3)
// Dis:    addis 3, 2, -1
// Dis:    addi 3, 2, -32744
