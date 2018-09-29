// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux %s -o %t.o
// RUN: ld.lld -fix-cortex-a53-843419 -verbose -t %t.o -o /dev/null | FileCheck %s
// Test cases for Cortex-A53 Erratum 843419 that we don't expect to recognize
// as needing a patch as one or more of the conditions isn't satisfied.
// See ARM-EPM-048406 Cortex_A53_MPCore_Software_Developers_Errata_Notice.pdf
// for full erratum details.
// In Summary
// 1.)
// ADRP (0xff8 or 0xffc)
// 2.)
// - load or store single register or either integer or vector registers
// - STP or STNP of either vector or vector registers
// - Advanced SIMD ST1 store instruction
// Must not write Rn
// 3.) optional instruction, can't be a branch, must not write Rn, may read Rn
// 4.) A load or store instruction from the Load/Store register unsigned
// immediate class using Rn as the base register

// Expect no patches detected.
// CHECK-NOT: detected cortex-a53-843419 erratum sequence

// erratum sequence but adrp (address & 0xfff) is not 0xff8 or 0xffc
        .section .text.01, "ax", %progbits
        .balign 4096
        .globl t3_0_ldr
        .type t3_ff8_ldr, %function
t3_0_ldr:
        adrp x0, dat
        ldr x1, [x1, #0]
        ldr x0, [x0, :got_lo12:dat]
        ret

        .section .text.02, "ax", %progbits
        .balign 4096
        .globl t3_ff4_ldr
        .space 4096 - 12
        .type t3_ff4_ldr, %function
t3_ff4_ldr:
        adrp x0, dat
        ldr x1, [x1, #0]
        ldr x0, [x0, :got_lo12:dat]
        ret

// Close matches for erratum sequence, with adrp at correct address but
// instruction 2 is a load or store but not one that matches the erratum
// conditions, but with a similar encoding to an instruction that does.

        // ldp is not part of sequence, although stp is.
        .section .text.03, "ax", %progbits
        .balign 4096
        .globl t3_ff8_ldp
        .type t3_ff8_ldp, %function
        .space 4096 - 8
t3_ff8_ldp:
        adrp x16, dat
        ldp x1,x2, [x3, #0]
        ldr x13, [x16, :got_lo12:dat]
        ret

        // st2 is not part of sequence although st1 is.
        .section .text.04, "ax", %progbits
        .balign 4096
        .globl t3_ffc_st2
        .type t3_ffc_st2, %function
        .space 4096 - 4
t3_ffc_st2:
        adrp x16, dat
        st2 { v0.16b, v1.16b }, [x1]
        ldr x13, [x16, :got_lo12:dat]
        ret

        // st3 is not part of sequence although st1 is.
        .section .text.05, "ax", %progbits
        .balign 4096
        .globl t3_ffc_st3
        .type t3_ffc_st3, %function
        .space 4096 - 4
t3_ffc_st3:
        adrp x16, dat
        st3 { v0.16b, v1.16b, v2.16b }, [x1], x2
        ldr x13, [x16, :got_lo12:dat]
        ret

        // ld1 is not part of sequence although st1 is.
        .section .text.06, "ax", %progbits
        .balign 4096
        .globl t3_ffc_ld2
        .type t3_ffc_st3, %function
        .space 4096 - 4
t3_ffc_ld1:
        adrp x16, dat
        ld1 { v0.16b }, [x2], x3
        ldr x13, [x16, :got_lo12:dat]
        ret

        // ldnp is not part of sequence although stnp is.
        .section .text.07, "ax", %progbits
        .balign 4096
        .globl t4_ff8_ldnp
        .type t4_ff8_ldnp, %function
        .space 4096 - 8
t4_ff8_ldnp:
        adrp x7, dat
        ldnp x1,x2, [x3, #0]
        nop
        ldr x10, [x7, :got_lo12:dat]
        ret

// Close match for erratum sequence, with adrp at correct address but
// instruction 2 writes to Rn, with Rn as either destination or as the
// transfer register but with writeback.

        // ldr instruction writes to Rn
        .section .text.08, "ax", %progbits
        .balign 4096
        .globl t3_ff8_ldr
        .type t3_ff8_ldr, %function
        .space 4096 - 8
t3_ff8_ldr:
        adrp x0, dat
        ldr x0, [x1, #0]
        ldr x0, [x0, :got_lo12:dat]
        ret

        // str instruction writes to Rn via writeback (pre index)
        .section .text.09, "ax", %progbits
        .balign 4096
        .globl t3_ff8_str
        .type t3_ff8_str, %function
        .space 4096 - 8
t3_ff8_str:
        adrp x0, dat
        str x1, [x0, #4]!
        ldr x0, [x0, :got_lo12:dat]
        ret

        // ldr instruction writes to Rn via writeback (post index)
        .section .text.09, "ax", %progbits
        .balign 4096
        .globl t3_ffc_ldr
        .type t3_ffc_ldr, %function
        .space 4096 - 8
t3_ffc_ldr:
        adrp x0, dat
        ldr x1, [x0], 0x8
        ldr x0, [x0, :got_lo12:dat]
        ret

        // stp writes to Rn via writeback (pre index)
        .section .text.10, "ax", %progbits
        .balign 4096
        .globl t4_ffc_stppre
        .type t4_ffc_stppre, %function
        .space 4096 - 4
t4_ffc_stppre:
        adrp x16, dat
        stp x1,x2, [x16, #16]!
        mul x3, x16, x16
        ldr x14, [x16, #8]
        ret

        // stp writes to Rn via writeback (post index)
        .section .text.11, "ax", %progbits
        .balign 4096
        .globl t4_ff8_stppost
        .type t4_ff8_stppost, %function
        .space 4096 - 8
t4_ff8_stppost:
        adrp x16, dat
        stp x1,x2, [x16], #16
        mul x3, x16, x16
        ldr x14, [x16, #8]
        ret

        // st1 writes to Rn via writeback
        .section .text.12, "ax", %progbits
        .balign 4096
        .globl t3_ff8_st1
        .type t3_ff8_st1, %function
        .space 4096 - 8
t3_ff8_st1:
        adrp x16, dat
        st1 { v0.16b}, [x16], x2
        ldr x13, [x16, :got_lo12:dat]
        ret

// Close match for erratum sequence, but with optional instruction 3 a branch

        // function call via immediate
        .section .text.13, "ax", %progbits
        .balign 4096
        .globl t4_ffc_blimm
        .type t4_ffc_blimm, %function
        .space 4096 - 4
t4_ffc_blimm:
        adrp x7, dat
        stnp x1,x2, [x3, #0]
        bl t4_ffc_blimm
        ldr x10, [x7, :got_lo12:dat]
        ret

        // function call via register
        .section .text.14, "ax", %progbits
        .balign 4096
        .globl t4_ffc_blreg
        .type t4_ffc_blreg, %function
        .space 4096 - 4
t4_ffc_blreg:
        adrp x7, dat
        stnp x1,x2, [x3, #0]
        blr x4
        ldr x10, [x7, :got_lo12:dat]
        ret

        // Unconditional branch immediate
        .section .text.15, "ax", %progbits
        .balign 4096
        .globl t4_ffc_branchimm
        .type t4_ffc_branchimm, %function
        .space 4096 - 4
t4_ffc_branchimm:
        adrp x7, dat
        stnp x1,x2, [x3, #0]
        b t4_ffc_branchimm
        ldr x10, [x7, :got_lo12:dat]
        ret

        // Unconditional branch register
        .section .text.16, "ax", %progbits
        .balign 4096
        .globl t4_ffc_branchreg
        .type t4_ffc_branchreg, %function
        .space 4096 - 4
t4_ffc_branchreg:
        adrp x7, dat
        stnp x1,x2, [x3, #0]
        br x4
        ldr x10, [x7, :got_lo12:dat]
        ret

        // Conditional branch
        .section .text.17, "ax", %progbits
        .balign 4096
        .globl t4_ffc_branchcond
        .type t4_ffc_branchcond, %function
        .space 4096 - 4
t4_ffc_branchcond:
        adrp x7, dat
        stnp x1,x2, [x3, #0]
        cbz x5, t4_ffc_branchcond
        ldr x10, [x7, :got_lo12:dat]
        ret

        // Conditional branch immediate
        .section .text.18, "ax", %progbits
        .balign 4096
        .globl t4_ffc_branchcondimm
        .type t4_ffc_branchcondimm, %function
        .space 4096 - 4
t4_ffc_branchcondimm:
        adrp x7, dat
        stnp x1,x2, [x3, #0]
        beq t4_ffc_branchcondimm
        ldr x10, [x7, :got_lo12:dat]
        ret

// Bitpattern matches erratum sequence but either all or part of the sequence
// is in inline literal data
        .section .text.19, "ax", %progbits
        .balign 4096
        .globl t3_ffc_ldrtraildata
        .type t3_ff8_ldrtraildata, %function
        .space 4096 - 8
t3_ff8_ldrtraildata:
        adrp x0, dat
        ldr x1, [x1, #0]
        // 0xf9400000 = ldr x0, [x0]
        .byte 0x00
        .byte 0x00
        .byte 0x40
        .byte 0xf9
        ldr x0, [x0, :got_lo12:dat]
        ret

        .section .text.20, "ax", %progbits
        .balign 4096
        .globl t3_ffc_ldrpredata
        .type t3_ff8_ldrpredata, %function
        .space 4096 - 8
t3_ff8_ldrpredata:
        // 0x90000000 = adrp x0, #0
        .byte 0x00
        .byte 0x00
        .byte 0x00
        .byte 0x90
        ldr x1, [x1, #0]
        ldr x0, [x0, :got_lo12:dat]
        ret

        .section .text.21, "ax", %progbits
        .balign 4096
        .globl t3_ffc_ldralldata
        .type t3_ff8_ldralldata, %function
        .space 4096 - 8
t3_ff8_ldralldata:
        // 0x90000000 = adrp x0, #0
        .byte 0x00
        .byte 0x00
        .byte 0x00
        .byte 0x90
        // 0xf9400021 = ldr x1, [x1]
        .byte 0x21
        .byte 0x00
        .byte 0x40
        .byte 0xf9
        // 0xf9400000 = ldr x0, [x0]
        .byte 0x00
        .byte 0x00
        .byte 0x40
        .byte 0xf9

        ret

        .text
        .globl _start
        .type _start, %function
_start:
        ret





// Bitpattern matches erratum sequence but section is not executable
        .data
        .globl dat
dat:    .word 0
