/* 	$NetBSD: sticio.h,v 1.6 2020/09/12 16:44:41 kamil Exp $	*/

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

#ifndef _TC_STICIO_H_
#define	_TC_STICIO_H_

#include <sys/ioccom.h>

/*
 * Buffer sizes.  Image buffers (span buffers, really) must be able to hold
 * 1280 32-bit pixels, even for the 8-bit boards.
 */
#define	STIC_XCOMM_SIZE		4096
#define	STIC_PACKET_SIZE	4096
#define	STIC_IMGBUF_SIZE	1280*4

/*
 * stic_xinfo: info about the board that can't be gleaned using the generic
 * wscons interfaces.
 */
struct stic_xinfo {
	int	sxi_stampw;		/* stamp width */
	int	sxi_stamph;		/* stamp height */
	int	sxi_unit;		/* control device unit (-1 == none) */
	u_int	sxi_buf_size;		/* total buffer size in bytes */
	u_int	sxi_buf_phys;		/* buffer PA (STIC address space) */
	u_int	sxi_buf_pktoff;		/* offset to packet buffers */
	u_int	sxi_buf_pktcnt;		/* packet buffer count */
	u_int	sxi_buf_imgoff;		/* offset to image buffers */
};

/*
 * stic_xcomm: Xserver communication area.  Used to communicate with the
 * kernel or i860 firmware when performing packet queueing or other such
 * funkiness.
 */
struct stic_xcomm {
	u_int	sxc_head;		/* Xserver submit pointer */
	u_int	sxc_tail;		/* STIC execute pointer */
	u_int	sxc_nreject;		/* number of rejected STIC polls */
	u_int	sxc_nstall;		/* number of queue stalls */
	u_int	sxc_busy;		/* true if STIC is busy */
	u_int	sxc_reserved[8];	/* reserved for future use */
	u_int	sxc_done[16];		/* packet completion semaphores */
};

#ifdef _KERNEL
/*
 * stic_xmap: a description of the area returned by mapping the board.
 * sxm_xcomm and sxm_buf are physically contigious and of variable size as a
 * whole; the combined size is learnt from stic_xinfo::sxi_buf_size.
 */
struct stic_xmap {
	u_int8_t	sxm_stic[NBPG];			/* STIC registers */
	u_int8_t	sxm_poll[0xc0000];		/* poll registers */
	u_int8_t	sxm_xcomm[256 * 1024];		/* X comms area */
};
#endif

/*
 * ioctl interface.
 */
#define	STICIO_GXINFO	_IOR('S', 0, struct stic_xinfo)
#define	STICIO_RESET	_IO('S', 1)
#define	STICIO_START860	_IO('S', 2)	/* PXG only, may disappear */
#define	STICIO_RESET860	_IO('S', 3)	/* PXG only, may disappear */
#define	STICIO_STARTQ	_IO('S', 4)	/* currently PX only */
#define	STICIO_STOPQ	_IO('S', 5)	/* currently PX only */

#endif	/* !_TC_STICIO_H_ */