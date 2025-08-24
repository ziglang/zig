/* 	$NetBSD: sticreg.h,v 1.9 2008/09/08 23:36:54 gmcgarry Exp $	*/

/*-
 * Copyright (c) 1999, 2000, 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Andrew Doran.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _TC_STICREG_H_
#define	_TC_STICREG_H_

/*
 * PixelStamp command packets take this general format:
 *
 * command word
 * plane mask & primitive count
 * always zero
 * update method
 *
 * per-packet context (optional):
 *      line width
 *      xy mask
 *	cliping rectangle min & max
 *	rgb constant
 *	z constant
 *
 * per-primitive context (optional):
 *      xy mask
 *      xy mask address
 *      primitive data (vertices, spans info, video)
 *      line width
 *      halfspace equals conditions
 *      rgb flat, or rgb{1,2,3} smooth
 *      z flat, or z{1,2,3} smooth
 */

/*
 * Command word.
 */

/* Base command */
#define	STAMP_CMD_POINTS        (0x0000)
#define	STAMP_CMD_LINES         (0x0001)
#define	STAMP_CMD_TRIANGLES     (0x0002)
#define	STAMP_CMD_COPYSPANS     (0x0005)
#define	STAMP_CMD_READSPANS     (0x0006)
#define	STAMP_CMD_WRITESPANS    (0x0007)
#define	STAMP_CMD_VIDEO         (0x0008)

/* Color */
#define	STAMP_RGB_NONE          (0x0000)
#define	STAMP_RGB_CONST         (0x0010)
#define	STAMP_RGB_FLAT          (0x0020)
#define	STAMP_RGB_SMOOTH        (0x0030)

/* Z */
#define	STAMP_Z_NONE            (0x0000)
#define	STAMP_Z_CONST           (0x0040)
#define	STAMP_Z_FLAT            (0x0080)
#define	STAMP_Z_SMOOTH          (0x00c0)

/* XYMASK */
#define	STAMP_XY_NONE           (0x0000)
#define	STAMP_XY_PERPACKET      (0x0100)
#define	STAMP_XY_PERPRIMATIVE   (0x0200)

/* Line width */
#define	STAMP_LW_NONE           (0x0000)
#define	STAMP_LW_PERPACKET      (0x0400)
#define	STAMP_LW_PERPRIMATIVE   (0x0800)

/* Miscellaneous flags */
#define	STAMP_CLIPRECT          (0x00080000)
#define	STAMP_MESH              (0x00200000)
#define	STAMP_AALINE            (0x00800000)
#define	STAMP_HS_EQUALS         (0x80000000)

/*
 * Update word.
 */

/* XXX What does this do? Perhaps for 96-bit boards? */
#define	STAMP_PLANE_8X3		(0 << 5)
#define	STAMP_PLANE_24		(1 << 5)

/* Write enable */
#define	STAMP_WE_SIGN		(0x04 << 8)
#define	STAMP_WE_XYMASK		(0x02 << 8)
#define	STAMP_WE_CLIPRECT	(0x01 << 8)
#define	STAMP_WE_NONE		(0x00 << 8)

/* Pixel write method */
#define	STAMP_METHOD_CLEAR	(0x60 << 12)
#define	STAMP_METHOD_AND	(0x14 << 12)
#define	STAMP_METHOD_ANDREV	(0x15 << 12)
#define	STAMP_METHOD_COPY	(0x20 << 12)
#define	STAMP_METHOD_ANDINV	(0x16 << 12)
#define	STAMP_METHOD_NOOP	(0x40 << 12)
#define	STAMP_METHOD_XOR	(0x11 << 12)
#define	STAMP_METHOD_OR		(0x0f << 12)
#define	STAMP_METHOD_NOR	(0x17 << 12)
#define	STAMP_METHOD_EQUIV	(0x10 << 12)
#define	STAMP_METHOD_INV	(0x4e << 12)
#define	STAMP_METHOD_ORREV	(0x0e << 12)
#define	STAMP_METHOD_COPYINV	(0x2d << 12)
#define	STAMP_METHOD_ORINV	(0x0d << 12)
#define	STAMP_METHOD_NAND	(0x0c << 12)
#define	STAMP_METHOD_SET	(0x6c << 12)
#define	STAMP_METHOD_SUM	(0x00 << 12)
#define	STAMP_METHOD_DIFF	(0x02 << 12)
#define	STAMP_METHOD_REVDIFF	(0x01 << 12)

/* Double buffering */
#define	STAMP_DB_NONE		(0x00 << 28)
#define	STAMP_DB_01		(0x01 << 28)
#define	STAMP_DB_12		(0x02 << 28)
#define	STAMP_DB_02		(0x04 << 28)

/* Miscellaneous flags */
#define	STAMP_UPDATE_ENABLE	(1 << 0)
#define	STAMP_SAVE_SIGN		(1 << 6)
#define	STAMP_SAVE_ALPHA	(1 << 7)
#define	STAMP_SUPERSAMPLE	(1 << 11)
#define	STAMP_SPAN		(1 << 19)
#define	STAMP_COPYSPAN_ALIGNED	(1 << 20)
#define	STAMP_MINMAX		(1 << 21)
#define	STAMP_MULT		(1 << 22)
#define	STAMP_MULTACC		(1 << 23)
#define	STAMP_HALF_BUFF		(1 << 27)
#define	STAMP_INITIALIZE	(1 << 31)

/*
 * XYMASK address calculation.
 */
#define	XMASKADDR(sw, sx, a)	(((a)-((sx) % (sw))) & 15)
#define	YMASKADDR(shm, sy, b)	(((b)-((sy) & (shm))) & 15)
#define	XYMASKADDR(sw,shm,x,y,a,b)	\
    (XMASKADDR(sw,x,a) << 16 | YMASKADDR(shm,y,b))

/*
 * Miscellenous constants.
 */
#define	STIC_MAGIC_X	370
#define	STIC_MAGIC_Y	37

/*
 * Poll register magic values.
 */
#define	STAMP_OK		(0)
#define	STAMP_BUSY		(1)
#define	STAMP_RETRIES		(100000)
#define	STAMP_DELAY		(10)

/*
 * STIC registers.
 */
struct stic_regs {
	u_int32_t	sr_pad0;
	u_int32_t	sr_pad1;
	u_int32_t	sr_hsync;
	u_int32_t	sr_hsync2;
	u_int32_t	sr_hblank;
	u_int32_t	sr_vsync;
	u_int32_t	sr_vblank;
	u_int32_t	sr_vtest;
	u_int32_t	sr_ipdvint;
	u_int32_t	sr_pad2;
	u_int32_t	sr_sticsr;
	u_int32_t	sr_busdat;
	u_int32_t	sr_busadr;
	u_int32_t	sr_pad3;
	u_int32_t	sr_buscsr;
	u_int32_t	sr_modcl;
} __packed;

/*
 * Bit definitions for stic_regs::sticsr.
 */
#define	STIC_CSR_TSTFNC		0x00000003
# define STIC_CSR_TSTFNC_NORMAL	0
# define STIC_CSR_TSTFNC_PARITY	1
# define STIC_CSR_TSTFNC_CNTPIX	2
# define STIC_CSR_TSTFNC_TSTDAC	3
#define	STIC_CSR_CHECKPAR	0x00000004
#define	STIC_CSR_STARTVT	0x00000010
#define	STIC_CSR_START		0x00000020
#define	STIC_CSR_RESET		0x00000040
#define	STIC_CSR_STARTST	0x00000080

/*
 * Bit definitions for stic_regs::int.  Three four-bit wide fields, for
 * error (E), vertical-blank (V), and packet-done (P) intererupts,
 * respectively.  The low-order three bits of each field are interrupt
 * enable, condition flagged, and nybble write enable.  The top bit of each
 * field is unused.
 */
#define	STIC_INT_E_EN		0x00000001
#define	STIC_INT_E		0x00000002
#define	STIC_INT_E_WE		0x00000004

#define	STIC_INT_V_EN		0x00000100
#define	STIC_INT_V		0x00000200
#define	STIC_INT_V_WE		0x00000400

#define	STIC_INT_P_EN		0x00010000
#define	STIC_INT_P		0x00020000
#define	STIC_INT_P_WE		0x00040000

#define	STIC_INT_E_MASK	(STIC_INT_E_EN | STIC_INT_E | STIC_INT_E_WE)
#define	STIC_INT_V_MASK	(STIC_INT_V_EN | STIC_INT_V | STIC_INT_V_WE)
#define	STIC_INT_P_MASK	(STIC_INT_P_EN | STIC_INT_P | STIC_INT_P_WE)
#define	STIC_INT_MASK	(STIC_INT_E_MASK | STIC_INT_P_MASK | STIC_INT_V_MASK)

#define	STIC_INT_WE	(STIC_INT_E_WE | STIC_INT_V_WE | STIC_INT_P_WE)
#define	STIC_INT_CLR	(STIC_INT_E_EN | STIC_INT_V_EN | STIC_INT_P_EN)

/*
 * On DMA: reading from a STIC poll register causes load & execution of
 * the packet at the correspoinding physical address.  Either STAMP_OK
 * or STAMP_BUSY will be returned to indicate status.
 *
 * The STIC sees only 23-bits (8MB) of address space.  Bits 21-22 in
 * physical address space map to bits 27-28, and bits 15-20 map to bits
 * 18-23 in the STIC's warped view of the word.  On the PXG, the STIC
 * sees only the onboard SRAM (so any `physical addresses' are offsets
 * into the beginning of the SRAM).
 */

#endif	/* _TC_STICREG_H_ */