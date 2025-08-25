/*
 * memset - fill memory with a constant byte
 *
 * Copyright (c) 2012-2020, Arm Limited.
 * SPDX-License-Identifier: MIT
 */

/* Assumptions:
 *
 * ARMv8-a, AArch64, Advanced SIMD, unaligned accesses.
 *
 */

#define dstin   x0
#define val     x1
#define valw    w1
#define count   x2
#define dst     x3
#define dstend  x4
#define zva_val x5

.global memset
.type memset,%function
memset:

	dup     v0.16B, valw
	add     dstend, dstin, count

	cmp     count, 96
	b.hi    .Lset_long
	cmp     count, 16
	b.hs    .Lset_medium
	mov     val, v0.D[0]

	/* Set 0..15 bytes.  */
	tbz     count, 3, 1f
	str     val, [dstin]
	str     val, [dstend, -8]
	ret
	nop
1:      tbz     count, 2, 2f
	str     valw, [dstin]
	str     valw, [dstend, -4]
	ret
2:      cbz     count, 3f
	strb    valw, [dstin]
	tbz     count, 1, 3f
	strh    valw, [dstend, -2]
3:      ret

	/* Set 17..96 bytes.  */
.Lset_medium:
	str     q0, [dstin]
	tbnz    count, 6, .Lset96
	str     q0, [dstend, -16]
	tbz     count, 5, 1f
	str     q0, [dstin, 16]
	str     q0, [dstend, -32]
1:      ret

	.p2align 4
	/* Set 64..96 bytes.  Write 64 bytes from the start and
	   32 bytes from the end.  */
.Lset96:
	str     q0, [dstin, 16]
	stp     q0, q0, [dstin, 32]
	stp     q0, q0, [dstend, -32]
	ret

	.p2align 4
.Lset_long:
	and     valw, valw, 255
	bic     dst, dstin, 15
	str     q0, [dstin]
	cmp     count, 160
	ccmp    valw, 0, 0, hs
	b.ne    .Lno_zva

#ifndef SKIP_ZVA_CHECK
	mrs     zva_val, dczid_el0
	and     zva_val, zva_val, 31
	cmp     zva_val, 4              /* ZVA size is 64 bytes.  */
	b.ne    .Lno_zva
#endif
	str     q0, [dst, 16]
	stp     q0, q0, [dst, 32]
	bic     dst, dst, 63
	sub     count, dstend, dst      /* Count is now 64 too large.  */
	sub     count, count, 128       /* Adjust count and bias for loop.  */

	.p2align 4
.Lzva_loop:
	add     dst, dst, 64
	dc      zva, dst
	subs    count, count, 64
	b.hi    .Lzva_loop
	stp     q0, q0, [dstend, -64]
	stp     q0, q0, [dstend, -32]
	ret

.Lno_zva:
	sub     count, dstend, dst      /* Count is 16 too large.  */
	sub     dst, dst, 16            /* Dst is biased by -32.  */
	sub     count, count, 64 + 16   /* Adjust count and bias for loop.  */
.Lno_zva_loop:
	stp     q0, q0, [dst, 32]
	stp     q0, q0, [dst, 64]!
	subs    count, count, 64
	b.hi    .Lno_zva_loop
	stp     q0, q0, [dstend, -64]
	stp     q0, q0, [dstend, -32]
	ret

.size memset,.-memset

