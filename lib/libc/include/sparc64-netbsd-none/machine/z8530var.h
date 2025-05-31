/*	$NetBSD: z8530var.h,v 1.13 2011/07/01 20:59:39 dyoung Exp $	*/

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)zsvar.h	8.1 (Berkeley) 6/11/93
 */

#include <sys/bus.h>
#include <dev/ic/z8530sc.h>

#include "kbd.h"	/* NKBD */

#if (NKBD > 0)
/*
 * Need to override cn_console_dev() for zstty and zskbd.
 */
#ifdef cn_isconsole
#undef cn_isconsole
#endif
extern struct consdev *cn_hw;
extern struct consdev *cn_tab;
#define cn_isconsole(d)	((d) == cn_tab->cn_dev || (d) == cn_hw->cn_dev)
#endif

struct zsc_softc {
	device_t		zsc_dev;	/* base device */
	bus_space_tag_t		zsc_bustag;	/* bus space/DMA tags */
	bus_dma_tag_t		zsc_dmatag;
	struct zs_chanstate	*zsc_cs[2];	/* channel A and B soft state */

	/* Machine-dependent part follows... */
	void			*zsc_softintr;
	int			zsc_promunit;	/* PROM's view of zs devices */
	int			zsc_node;	/* PROM node, if any */
	struct evcnt		zsc_intrcnt;	/* count interrupts */
	struct zs_chanstate	zsc_cs_store[2];
};

/*
 * Functions to read and write individual registers in a channel.
 * The ZS chip requires a 1.6 uSec. recovery time between accesses.
 * On the SparcStation the recovery time is handled in hardware.
 * On the older Sun4 machine it isn't, and software must do it.
 *
 * However, it *is* a problem on some Sun4m's (i.e. the SS20) (XXX: why?).
 * Thus we leave in the delay (done in the functions below).
 * XXX: (ABB) Think about this more.
 *
 * The functions below could be macros instead if we are concerned
 * about the function call overhead where ZS_DELAY does nothing.
 */

uint8_t zs_read_reg(struct zs_chanstate *cs, uint8_t reg);
uint8_t zs_read_csr(struct zs_chanstate *cs);
uint8_t zs_read_data(struct zs_chanstate *cs);

void  zs_write_reg(struct zs_chanstate *cs, uint8_t reg, uint8_t val);
void  zs_write_csr(struct zs_chanstate *cs, uint8_t val);
void  zs_write_data(struct zs_chanstate *cs, uint8_t val);

/* The sparc has splzs() in psl.h */

/* We want to call it "zs" instead of "zsc" (sigh). */
#ifndef ZSCCF_CHANNEL
#define ZSCCF_CHANNEL 0
#define ZSCCF_CHANNEL_DEFAULT -1
#endif

#undef cn_trap
#define cn_trap() zs_abort(NULL)

#define	IPL_ZS	IPL_SERIAL