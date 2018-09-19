// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux %s -o %t.o
// RUN: ld.lld -fix-cortex-a53-843419 -verbose %t.o -o %t2 2>&1 | FileCheck -check-prefix CHECK-PRINT %s
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t2 | FileCheck %s -check-prefixes=CHECK,CHECK-FIX
// RUN: ld.lld %t.o -o %t3
// RUN: llvm-objdump -triple=aarch64-linux-gnu -d %t3 | FileCheck %s -check-prefixes=CHECK,CHECK-NOFIX
// Test cases for Cortex-A53 Erratum 843419
// See ARM-EPM-048406 Cortex_A53_MPCore_Software_Developers_Errata_Notice.pdf
// for full erratum details.
// In Summary
// 1.)
// ADRP (0xff8 or 0xffc).
// 2.)
// - load or store single register or either integer or vector registers.
// - STP or STNP of either vector or vector registers.
// - Advanced SIMD ST1 store instruction.
// - Must not write Rn.
// 3.) optional instruction, can't be a branch, must not write Rn, may read Rn.
// 4.) A load or store instruction from the Load/Store register unsigned
// immediate class using Rn as the base register.

// Each section contains a sequence of instructions that should be recognized
// as erratum 843419. The test cases cover the major variations such as:
// - adrp starts at 0xfff8 or 0xfffc.
// - Variations in instruction class for instruction 2.
// - Optional instruction 3 present or not.
// - Load or store for instruction 4.

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 21FF8 in unpatched output.
// CHECK: t3_ff8_ldr:
// CHECK-NEXT:    21ff8:        e0 01 00 f0     adrp    x0, #258048
// CHECK-NEXT:    21ffc:        21 00 40 f9     ldr             x1, [x1]
// CHECK-FIX:     22000:        03 c8 00 14     b       #204812
// CHECK-NOFIX:   22000:        00 00 40 f9     ldr             x0, [x0]
// CHECK-NEXT:    22004:        c0 03 5f d6     ret
        .section .text.01, "ax", %progbits
        .balign 4096
        .globl t3_ff8_ldr
        .type t3_ff8_ldr, %function
        .space 4096 - 8
t3_ff8_ldr:
        adrp x0, dat1
        ldr x1, [x1, #0]
        ldr x0, [x0, :got_lo12:dat1]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 23FF8 in unpatched output.
// CHECK: t3_ff8_ldrsimd:
// CHECK-NEXT:    23ff8:        e0 01 00 b0     adrp    x0, #249856
// CHECK-NEXT:    23ffc:        21 00 40 bd     ldr             s1, [x1]
// CHECK-FIX:     24000:        05 c0 00 14     b       #196628
// CHECK-NOFIX:   24000:        02 04 40 f9     ldr     x2, [x0, #8]
// CHECK-NEXT:    24004:        c0 03 5f d6     ret
        .section .text.02, "ax", %progbits
        .balign 4096
        .globl t3_ff8_ldrsimd
        .type t3_ff8_ldrsimd, %function
        .space 4096 - 8
t3_ff8_ldrsimd:
        adrp x0, dat2
        ldr s1, [x1, #0]
        ldr x2, [x0, :got_lo12:dat2]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 25FFC in unpatched output.
// CHECK: t3_ffc_ldrpost:
// CHECK-NEXT:    25ffc:        c0 01 00 f0     adrp    x0, #241664
// CHECK-NEXT:    26000:        21 84 40 bc     ldr     s1, [x1], #8
// CHECK-FIX:     26004:        06 b8 00 14     b       #188440
// CHECK-NOFIX:   26004:        03 08 40 f9     ldr     x3, [x0, #16]
// CHECK-NEXT:    26008:        c0 03 5f d6     ret
        .section .text.03, "ax", %progbits
        .balign 4096
        .globl t3_ffc_ldrpost
        .type t3_ffc_ldrpost, %function
        .space 4096 - 4
t3_ffc_ldrpost:
        adrp x0, dat3
        ldr s1, [x1], #8
        ldr x3, [x0, :got_lo12:dat3]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 27FF8 in unpatched output.
// CHECK: t3_ff8_strpre:
// CHECK-NEXT:    27ff8:        c0 01 00 b0     adrp    x0, #233472
// CHECK-NEXT:    27ffc:        21 8c 00 bc     str     s1, [x1, #8]!
// CHECK-FIX:     28000:        09 b0 00 14     b       #180260
// CHECK-NOFIX:   28000:        02 00 40 f9     ldr             x2, [x0]
// CHECK-NEXT:    28004:        c0 03 5f d6     ret
        .section .text.04, "ax", %progbits
        .balign 4096
        .globl t3_ff8_strpre
        .type t3_ff8_strpre, %function
        .space 4096 - 8
t3_ff8_strpre:
        adrp x0, dat1
        str s1, [x1, #8]!
        ldr x2, [x0, :lo12:dat1]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 29FFC in unpatched output.
// CHECK: t3_ffc_str:
// CHECK-NEXT:    29ffc:        bc 01 00 f0     adrp    x28, #225280
// CHECK-NEXT:    2a000:        42 00 00 f9     str             x2, [x2]
// CHECK-FIX:     2a004:        0a a8 00 14     b       #172072
// CHECK-NOFIX:   2a004:        9c 07 00 f9     str     x28, [x28, #8]
// CHECK-NEXT:    2a008:        c0 03 5f d6     ret
        .section .text.05, "ax", %progbits
        .balign 4096
        .globl t3_ffc_str
        .type t3_ffc_str, %function
        .space 4096 - 4
t3_ffc_str:
        adrp x28, dat2
        str x2, [x2, #0]
        str x28, [x28, :lo12:dat2]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 2BFFC in unpatched output.
// CHECK: t3_ffc_strsimd:
// CHECK-NEXT:    2bffc:        bc 01 00 b0     adrp    x28, #217088
// CHECK-NEXT:    2c000:        44 00 00 b9     str             w4, [x2]
// CHECK-FIX:     2c004:        0c a0 00 14     b       #163888
// CHECK-NOFIX:   2c004:        84 0b 00 f9     str     x4, [x28, #16]
// CHECK-NEXT:    2c008:        c0 03 5f d6     ret
        .section .text.06, "ax", %progbits
        .balign 4096
        .globl t3_ffc_strsimd
        .type t3_ffc_strsimd, %function
        .space 4096 - 4
t3_ffc_strsimd:
        adrp x28, dat3
        str w4, [x2, #0]
        str x4, [x28, :lo12:dat3]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 2DFF8 in unpatched output.
// CHECK: t3_ff8_ldrunpriv:
// CHECK-NEXT:    2dff8:        9d 01 00 f0     adrp    x29, #208896
// CHECK-NEXT:    2dffc:        41 08 40 38     ldtrb           w1, [x2]
// CHECK-FIX:     2e000:        0f 98 00 14     b       #155708
// CHECK-NOFIX:   2e000:        bd 03 40 f9     ldr             x29, [x29]
// CHECK-NEXT:    2e004:        c0 03 5f d6     ret
        .section .text.07, "ax", %progbits
        .balign 4096
        .globl t3_ff8_ldrunpriv
        .type t3_ff8_ldrunpriv, %function
        .space 4096 - 8
t3_ff8_ldrunpriv:
        adrp x29, dat1
        ldtrb w1, [x2, #0]
        ldr x29, [x29, :got_lo12:dat1]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 2FFFC in unpatched output.
// CHECK: t3_ffc_ldur:
// CHECK-NEXT:    2fffc:        9d 01 00 b0     adrp    x29, #200704
// CHECK-NEXT:    30000:        42 40 40 b8     ldur    w2, [x2, #4]
// CHECK-FIX:     30004:        10 90 00 14     b       #147520
// CHECK-NOFIX:   30004:        bd 07 40 f9     ldr     x29, [x29, #8]
// CHECK-NEXT:    30008:        c0 03 5f d6     ret
        .balign 4096
        .globl t3_ffc_ldur
        .type t3_ffc_ldur, %function
        .space 4096 - 4
t3_ffc_ldur:
        adrp x29, dat2
        ldur w2, [x2, #4]
        ldr x29, [x29, :got_lo12:dat2]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 31FFC in unpatched output.
// CHECK: t3_ffc_sturh:
// CHECK-NEXT:    31ffc:        72 01 00 f0     adrp    x18, #192512
// CHECK-NEXT:    32000:        43 40 00 78     sturh   w3, [x2, #4]
// CHECK-FIX:     32004:        12 88 00 14     b       #139336
// CHECK-NOFIX:   32004:        41 0a 40 f9     ldr     x1, [x18, #16]
// CHECK-NEXT:    32008:        c0 03 5f d6     ret
        .section .text.09, "ax", %progbits
        .balign 4096
        .globl t3_ffc_sturh
        .type t3_ffc_sturh, %function
        .space 4096 - 4
t3_ffc_sturh:
        adrp x18, dat3
        sturh w3, [x2, #4]
        ldr x1, [x18, :got_lo12:dat3]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 33FF8 in unpatched output.
// CHECK: t3_ff8_literal:
// CHECK-NEXT:    33ff8:        72 01 00 b0     adrp    x18, #184320
// CHECK-NEXT:    33ffc:        e3 ff ff 58     ldr     x3, #-4
// CHECK-FIX:     34000:        15 80 00 14     b       #131156
// CHECK-NOFIX:   34000:        52 02 40 f9     ldr             x18, [x18]
// CHECK-NEXT:    34004:        c0 03 5f d6     ret
        .section .text.10, "ax", %progbits
        .balign 4096
        .globl t3_ff8_literal
        .type t3_ff8_literal, %function
        .space 4096 - 8
t3_ff8_literal:
        adrp x18, dat1
        ldr x3, t3_ff8_literal
        ldr x18, [x18, :lo12:dat1]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 35FFC in unpatched output.
// CHECK: t3_ffc_register:
// CHECK-NEXT:    35ffc:        4f 01 00 f0     adrp    x15, #176128
// CHECK-NEXT:    36000:        43 68 61 f8     ldr             x3, [x2, x1]
// CHECK-FIX:     36004:        16 78 00 14     b       #122968
// CHECK-NOFIX:   36004:        ea 05 40 f9     ldr     x10, [x15, #8]
// CHECK-NEXT:    36008:        c0 03 5f d6     ret
        .section .text.11, "ax", %progbits
        .balign 4096
        .globl t3_ffc_register
        .type t3_ffc_register, %function
        .space 4096 - 4
t3_ffc_register:
        adrp x15, dat2
        ldr x3, [x2, x1]
        ldr x10, [x15, :lo12:dat2]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 37FF8 in unpatched output.
// CHECK: t3_ff8_stp:
// CHECK-NEXT:    37ff8:        50 01 00 b0     adrp    x16, #167936
// CHECK-NEXT:    37ffc:        61 08 00 a9     stp             x1, x2, [x3]
// CHECK-FIX:     38000:        19 70 00 14     b       #114788
// CHECK-NOFIX:   38000:        0d 0a 40 f9     ldr     x13, [x16, #16]
// CHECK-NEXT:    38004:        c0 03 5f d6     ret
        .section .text.12, "ax", %progbits
        .balign 4096
        .globl t3_ff8_stp
        .type t3_ff8_stp, %function
        .space 4096 - 8
t3_ff8_stp:
        adrp x16, dat3
        stp x1,x2, [x3, #0]
        ldr x13, [x16, :lo12:dat3]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 39FFC in unpatched output.
// CHECK: t3_ffc_stnp:
// CHECK-NEXT:    39ffc:        27 01 00 f0     adrp    x7, #159744
// CHECK-NEXT:    3a000:        61 08 00 a8     stnp            x1, x2, [x3]
// CHECK-FIX:     3a004:        1a 68 00 14     b       #106600
// CHECK-NOFIX:   3a004:        e9 00 40 f9     ldr             x9, [x7]
// CHECK-NEXT:    3a008:        c0 03 5f d6     ret
        .section .text.13, "ax", %progbits
        .balign 4096
        .globl t3_ffc_stnp
        .type t3_ffc_stnp, %function
        .space 4096 - 4
t3_ffc_stnp:
        adrp x7, dat1
        stnp x1,x2, [x3, #0]
        ldr x9, [x7, :lo12:dat1]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 3BFFC in unpatched output.
// CHECK: t3_ffc_st1singlepost:
// CHECK-NEXT:    3bffc:        37 01 00 b0     adrp    x23, #151552
// CHECK-NEXT:    3c000:        20 04 82 0d     st1 { v0.b }[1], [x1], x2
// CHECK-FIX:     3c004:        1c 60 00 14     b       #98416
// CHECK-NOFIX:   3c004:        f6 06 40 f9     ldr     x22, [x23, #8]
// CHECK-NEXT:    3c008:        c0 03 5f d6     ret
        .section .text.14, "ax", %progbits
        .balign 4096
        .globl t3_ffc_st1singlepost
        .type t3_ffc_st1singlepost, %function
        .space 4096 - 4
t3_ffc_st1singlepost:
        adrp x23, dat2
        st1 { v0.b }[1], [x1], x2
        ldr x22, [x23, :lo12:dat2]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 3DFF8 in unpatched output.
// CHECK: t3_ff8_st1multiple:
// CHECK-NEXT:    3dff8:        17 01 00 f0     adrp    x23, #143360
// CHECK-NEXT:    3dffc:        20 a0 00 4c     st1     { v0.16b, v1.16b }, [x1]
// CHECK-FIX:     3e000:        1f 58 00 14     b       #90236
// CHECK-NOFIX:   3e000:        f8 0a 40 f9     ldr     x24, [x23, #16]
// CHECK-NEXT:    3e004:        c0 03 5f d6     ret
        .section .text.15, "ax", %progbits
        .balign 4096
        .globl t3_ff8_st1multiple
        .type t3_ff8_st1muliple, %function
        .space 4096 - 8
t3_ff8_st1multiple:
        adrp x23, dat3
        st1 { v0.16b, v1.16b }, [x1]
        ldr x24, [x23, :lo12:dat3]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 3FFF8 in unpatched output.
// CHECK: t4_ff8_ldr:
// CHECK-NEXT:    3fff8:        00 01 00 b0     adrp    x0, #135168
// CHECK-NEXT:    3fffc:        21 00 40 f9     ldr             x1, [x1]
// CHECK-NEXT:    40000:        42 00 00 8b     add             x2, x2, x0
// CHECK-FIX:     40004:        20 50 00 14     b       #82048
// CHECK-NOFIX:   40004:        02 00 40 f9     ldr             x2, [x0]
// CHECK-NEXT:    40008:        c0 03 5f d6     ret
        .section .text.16, "ax", %progbits
        .balign 4096
        .globl t4_ff8_ldr
        .type t4_ff8_ldr, %function
        .space 4096 - 8
t4_ff8_ldr:
        adrp x0, dat1
        ldr x1, [x1, #0]
        add x2, x2, x0
        ldr x2, [x0, :got_lo12:dat1]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 41FFC in unpatched output.
// CHECK: t4_ffc_str:
// CHECK-NEXT:    41ffc:        fc 00 00 f0     adrp    x28, #126976
// CHECK-NEXT:    42000:        42 00 00 f9     str             x2, [x2]
// CHECK-NEXT:    42004:        20 00 02 cb     sub             x0, x1, x2
// CHECK-FIX:     42008:        21 48 00 14     b       #73860
// CHECK-NOFIX:   42008:        9b 07 00 f9     str     x27, [x28, #8]
// CHECK-NEXT:    4200c:        c0 03 5f d6     ret
        .section .text.17, "ax", %progbits
        .balign 4096
        .globl t4_ffc_str
        .type t4_ffc_str, %function
        .space 4096 - 4
t4_ffc_str:
        adrp x28, dat2
        str x2, [x2, #0]
        sub x0, x1, x2
        str x27, [x28, :got_lo12:dat2]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 43FF8 in unpatched output.
// CHECK: t4_ff8_stp:
// CHECK-NEXT:    43ff8:        f0 00 00 b0     adrp    x16, #118784
// CHECK-NEXT:    43ffc:        61 08 00 a9     stp             x1, x2, [x3]
// CHECK-NEXT:    44000:        03 7e 10 9b     mul             x3, x16, x16
// CHECK-FIX:     44004:        24 40 00 14     b       #65680
// CHECK-NOFIX:   44004:        0e 0a 40 f9     ldr     x14, [x16, #16]
// CHECK-NEXT:    44008:        c0 03 5f d6     ret
        .section .text.18, "ax", %progbits
        .balign 4096
        .globl t4_ff8_stp
        .type t4_ff8_stp, %function
        .space 4096 - 8
t4_ff8_stp:
        adrp x16, dat3
        stp x1,x2, [x3, #0]
        mul x3, x16, x16
        ldr x14, [x16, :got_lo12:dat3]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 45FF8 in unpatched output.
// CHECK: t4_ff8_stppre:
// CHECK-NEXT:    45ff8:        d0 00 00 f0     adrp    x16, #110592
// CHECK-NEXT:    45ffc:        61 08 81 a9     stp     x1, x2, [x3, #16]!
// CHECK-NEXT:    46000:        03 7e 10 9b     mul             x3, x16, x16
// CHECK-FIX:     46004:        26 38 00 14     b       #57496
// CHECK-NOFIX:   46004:        0e 06 40 f9     ldr     x14, [x16, #8]
// CHECK-NEXT:    46008:        c0 03 5f d6     ret
        .section .text.19, "ax", %progbits
        .balign 4096
        .globl t4_ff8_stppre
        .type t4_ff8_stppre, %function
        .space 4096 - 8
t4_ff8_stppre:
        adrp x16, dat1
        stp x1,x2, [x3, #16]!
        mul x3, x16, x16
        ldr x14, [x16, #8]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 47FF8 in unpatched output.
// CHECK: t4_ff8_stppost:
// CHECK-NEXT:    47ff8:        d0 00 00 b0     adrp    x16, #102400
// CHECK-NEXT:    47ffc:        61 08 81 a8     stp     x1, x2, [x3], #16
// CHECK-NEXT:    48000:        03 7e 10 9b     mul             x3, x16, x16
// CHECK-FIX:     48004:        28 30 00 14     b       #49312
// CHECK-NOFIX:   48004:        0e 06 40 f9     ldr     x14, [x16, #8]
// CHECK-NEXT:    48008:        c0 03 5f d6     ret
        .section .text.20, "ax", %progbits
        .balign 4096
        .globl t4_ff8_stppost
        .type t4_ff8_stppost, %function
        .space 4096 - 8
t4_ff8_stppost:
        adrp x16, dat2
        stp x1,x2, [x3], #16
        mul x3, x16, x16
        ldr x14, [x16, #8]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 49FFC in unpatched output.
// CHECK: t4_ffc_stpsimd:
// CHECK-NEXT:    49ffc:        b0 00 00 f0     adrp    x16, #94208
// CHECK-NEXT:    4a000:        61 08 00 ad     stp             q1, q2, [x3]
// CHECK-NEXT:    4a004:        03 7e 10 9b     mul             x3, x16, x16
// CHECK-FIX:     4a008:        29 28 00 14     b       #41124
// CHECK-NOFIX:   4a008:        0e 06 40 f9     ldr     x14, [x16, #8]
// CHECK-NEXT:    4a00c:        c0 03 5f d6     ret
        .section .text.21, "ax", %progbits
        .balign 4096
        .globl t4_ffc_stpsimd
        .type t4_ffc_stpsimd, %function
        .space 4096 - 4
t4_ffc_stpsimd:
        adrp x16, dat3
        stp q1,q2, [x3, #0]
        mul x3, x16, x16
        ldr x14, [x16, #8]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 4BFFC in unpatched output.
// CHECK: t4_ffc_stnp:
// CHECK-NEXT:    4bffc:        a7 00 00 b0     adrp    x7, #86016
// CHECK-NEXT:    4c000:        61 08 00 a8     stnp            x1, x2, [x3]
// CHECK-NEXT:    4c004:        1f 20 03 d5     nop
// CHECK-FIX:     4c008:        2b 20 00 14     b       #32940
// CHECK-NOFIX:   4c008:        ea 00 40 f9     ldr             x10, [x7]
// CHECK-NEXT:    4c00c:        c0 03 5f d6     ret
        .section .text.22, "ax", %progbits
        .balign 4096
        .globl t4_ffc_stnp
        .type t4_ffc_stnp, %function
        .space 4096 - 4
t4_ffc_stnp:
        adrp x7, dat1
        stnp x1,x2, [x3, #0]
        nop
        ldr x10, [x7, :got_lo12:dat1]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 4DFFC in unpatched output.
// CHECK: t4_ffc_st1:
// CHECK-NEXT:    4dffc:        98 00 00 f0     adrp    x24, #77824
// CHECK-NEXT:    4e000:        20 80 00 4d     st1 { v0.s }[2], [x1]
// CHECK-NEXT:    4e004:        f6 06 40 f9     ldr     x22, [x23, #8]
// CHECK-FIX:     4e008:        2d 18 00 14     b       #24756
// CHECK-NOFIX:   4e008:        18 ff 3f f9     str     x24, [x24, #32760]
// CHECK-NEXT:    4e00c:        c0 03 5f d6     ret
        .section .text.23, "ax", %progbits
        .balign 4096
        .globl t4_ffc_st1
        .type t4_ffc_st1, %function
        .space 4096 - 4
t4_ffc_st1:
        adrp x24, dat2
        st1 { v0.s }[2], [x1]
        ldr x22, [x23, :got_lo12:dat2]
        str x24, [x24, #32760]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 4FFF8 in unpatched output.
// CHECK: t3_ff8_ldr_once:
// CHECK-NEXT:    4fff8:        80 00 00 b0     adrp    x0, #69632
// CHECK-NEXT:    4fffc:        20 70 82 4c     st1     { v0.16b }, [x1], x2
// CHECK-FIX:     50000:        31 10 00 14     b       #16580
// CHECK-NOFIX:   50000:        01 08 40 f9     ldr     x1, [x0, #16]
// CHECK-NEXT:    50004:        02 08 40 f9     ldr     x2, [x0, #16]
// CHECK-NEXT:    50008:        c0 03 5f d6     ret
        .section .text.24, "ax", %progbits
        .balign 4096
        .globl t3_ff8_ldr_once
        .type t3_ff8_ldr_once, %function
        .space 4096 - 8
t3_ff8_ldr_once:
        adrp x0, dat3
        st1 { v0.16b }, [x1], x2
        ldr x1, [x0, #16]
        ldr x2, [x0, #16]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 51FF8 in unpatched output.
// CHECK: t3_ff8_ldxr:
// CHECK-NEXT:    51ff8:        60 00 00 f0     adrp    x0, #61440
// CHECK-NEXT:    51ffc:        03 7c 5f c8     ldxr    x3, [x0]
// CHECK-FIX:     52000:        33 08 00 14     b       #8396
// CHECK-NOFIX:   52000:        01 08 40 f9     ldr     x1, [x0, #16]
// CHECK:         52004:        02 08 40 f9     ldr     x2, [x0, #16]
// CHECK-NEXT:    52008:        c0 03 5f d6     ret
        .section .text.25, "ax", %progbits
        .balign 4096
        .globl t3_ff8_ldxr
        .type t3_ff8_ldxr, %function
        .space 4096 - 8
t3_ff8_ldxr:
        adrp x0, dat3
        ldxr x3, [x0]
        ldr x1, [x0, #16]
        ldr x2, [x0, #16]
        ret

// CHECK-PRINT: detected cortex-a53-843419 erratum sequence starting at 53FF8 in unpatched output.
// CHECK: t3_ff8_stxr:
// CHECK-NEXT:    53ff8:        60 00 00 b0     adrp    x0, #53248
// CHECK-NEXT:    53ffc:        03 7c 04 c8     stxr    w4, x3, [x0]
// CHECK-FIX:     54000:        35 00 00 14     b       #212
// CHECK-NOFIX:   54000:        01 08 40 f9     ldr     x1, [x0, #16]
// CHECK:         54004:        02 08 40 f9     ldr     x2, [x0, #16]
// CHECK-NEXT:    54008:        c0 03 5f d6     ret
        .section .text.26, "ax", %progbits
        .balign 4096
        .globl t3_ff8_stxr
        .type t3_ff8_stxr, %function
        .space 4096 - 8
t3_ff8_stxr:
        adrp x0, dat3
        stxr w4, x3, [x0]
        ldr x1, [x0, #16]
        ldr x2, [x0, #16]
        ret

        .text
        .globl _start
        .type _start, %function
_start:
        ret

// CHECK-FIX: __CortexA53843419_22000:
// CHECK-FIX-NEXT:    5400c:    00 00 40 f9     ldr     x0, [x0]
// CHECK-FIX-NEXT:    54010:    fd 37 ff 17     b       #-204812
// CHECK-FIX: __CortexA53843419_24000:
// CHECK-FIX-NEXT:    54014:    02 04 40 f9     ldr     x2, [x0, #8]
// CHECK-FIX-NEXT:    54018:    fb 3f ff 17     b       #-196628
// CHECK-FIX: __CortexA53843419_26004:
// CHECK-FIX-NEXT:    5401c:    03 08 40 f9     ldr     x3, [x0, #16]
// CHECK-FIX-NEXT:    54020:    fa 47 ff 17     b       #-188440
// CHECK-FIX: __CortexA53843419_28000:
// CHECK-FIX-NEXT:    54024:    02 00 40 f9     ldr     x2, [x0]
// CHECK-FIX-NEXT:    54028:    f7 4f ff 17     b       #-180260
// CHECK-FIX: __CortexA53843419_2A004:
// CHECK-FIX-NEXT:    5402c:    9c 07 00 f9     str     x28, [x28, #8]
// CHECK-FIX-NEXT:    54030:    f6 57 ff 17     b       #-172072
// CHECK-FIX: __CortexA53843419_2C004:
// CHECK-FIX-NEXT:    54034:    84 0b 00 f9     str     x4, [x28, #16]
// CHECK-FIX-NEXT:    54038:    f4 5f ff 17     b       #-163888
// CHECK-FIX: __CortexA53843419_2E000:
// CHECK-FIX-NEXT:    5403c:    bd 03 40 f9     ldr     x29, [x29]
// CHECK-FIX-NEXT:    54040:    f1 67 ff 17     b       #-155708
// CHECK-FIX: __CortexA53843419_30004:
// CHECK-FIX-NEXT:    54044:    bd 07 40 f9     ldr     x29, [x29, #8]
// CHECK-FIX-NEXT:    54048:    f0 6f ff 17     b       #-147520
// CHECK-FIX: __CortexA53843419_32004:
// CHECK-FIX-NEXT:    5404c:    41 0a 40 f9     ldr     x1, [x18, #16]
// CHECK-FIX-NEXT:    54050:    ee 77 ff 17     b       #-139336
// CHECK-FIX: __CortexA53843419_34000:
// CHECK-FIX-NEXT:    54054:    52 02 40 f9     ldr     x18, [x18]
// CHECK-FIX-NEXT:    54058:    eb 7f ff 17     b       #-131156
// CHECK-FIX: __CortexA53843419_36004:
// CHECK-FIX-NEXT:    5405c:    ea 05 40 f9     ldr     x10, [x15, #8]
// CHECK-FIX-NEXT:    54060:    ea 87 ff 17     b       #-122968
// CHECK-FIX: __CortexA53843419_38000:
// CHECK-FIX-NEXT:    54064:    0d 0a 40 f9     ldr     x13, [x16, #16]
// CHECK-FIX-NEXT:    54068:    e7 8f ff 17     b       #-114788
// CHECK-FIX: __CortexA53843419_3A004:
// CHECK-FIX-NEXT:    5406c:    e9 00 40 f9     ldr     x9, [x7]
// CHECK-FIX-NEXT:    54070:    e6 97 ff 17     b       #-106600
// CHECK-FIX: __CortexA53843419_3C004:
// CHECK-FIX-NEXT:    54074:    f6 06 40 f9     ldr     x22, [x23, #8]
// CHECK-FIX-NEXT:    54078:    e4 9f ff 17     b       #-98416
// CHECK-FIX: __CortexA53843419_3E000:
// CHECK-FIX-NEXT:    5407c:    f8 0a 40 f9     ldr     x24, [x23, #16]
// CHECK-FIX-NEXT:    54080:    e1 a7 ff 17     b       #-90236
// CHECK-FIX: __CortexA53843419_40004:
// CHECK-FIX-NEXT:    54084:    02 00 40 f9     ldr     x2, [x0]
// CHECK-FIX-NEXT:    54088:    e0 af ff 17     b       #-82048
// CHECK-FIX: __CortexA53843419_42008:
// CHECK-FIX-NEXT:    5408c:    9b 07 00 f9     str     x27, [x28, #8]
// CHECK-FIX-NEXT:    54090:    df b7 ff 17     b       #-73860
// CHECK-FIX: __CortexA53843419_44004:
// CHECK-FIX-NEXT:    54094:    0e 0a 40 f9     ldr     x14, [x16, #16]
// CHECK-FIX-NEXT:    54098:    dc bf ff 17     b       #-65680
// CHECK-FIX: __CortexA53843419_46004:
// CHECK-FIX-NEXT:    5409c:    0e 06 40 f9     ldr     x14, [x16, #8]
// CHECK-FIX-NEXT:    540a0:    da c7 ff 17     b       #-57496
// CHECK-FIX: __CortexA53843419_48004:
// CHECK-FIX-NEXT:    540a4:    0e 06 40 f9     ldr     x14, [x16, #8]
// CHECK-FIX-NEXT:    540a8:    d8 cf ff 17     b       #-49312
// CHECK-FIX: __CortexA53843419_4A008:
// CHECK-FIX-NEXT:    540ac:    0e 06 40 f9     ldr     x14, [x16, #8]
// CHECK-FIX-NEXT:    540b0:    d7 d7 ff 17     b       #-41124
// CHECK-FIX: __CortexA53843419_4C008:
// CHECK-FIX-NEXT:    540b4:    ea 00 40 f9     ldr     x10, [x7]
// CHECK-FIX-NEXT:    540b8:    d5 df ff 17     b       #-32940
// CHECK-FIX: __CortexA53843419_4E008:
// CHECK-FIX-NEXT:    540bc:    18 ff 3f f9     str     x24, [x24, #32760]
// CHECK-FIX-NEXT:    540c0:    d3 e7 ff 17     b       #-24756
// CHECK-FIX: __CortexA53843419_50000:
// CHECK-FIX-NEXT:    540c4:    01 08 40 f9     ldr     x1, [x0, #16]
// CHECK-FIX-NEXT:    540c8:    cf ef ff 17     b       #-16580
// CHECK-FIX: __CortexA53843419_52000:
// CHECK-FIX-NEXT:    540cc:    01 08 40 f9     ldr     x1, [x0, #16]
// CHECK-FIX-NEXT:    540d0:    cd f7 ff 17     b       #-8396
// CHECK-FIX: __CortexA53843419_54000:
// CHECK-FIX-NEXT:    540d4:    01 08 40 f9     ldr     x1, [x0, #16]
// CHECK-FIX-NEXT:    540d8:    cb ff ff 17     b       #-212
        .data
        .globl dat
        .globl dat2
        .globl dat3
dat1:   .quad 1
dat2:   .quad 2
dat3:   .quad 3
