/*	$NetBSD: iopio.h,v 1.9 2022/04/17 21:24:53 andvar Exp $	*/

/*-
 * Copyright (c) 2000, 2001 The NetBSD Foundation, Inc.
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

#ifndef _I2O_IOPIO_H_
#define	_I2O_IOPIO_H_

#include <sys/types.h>
#include <sys/ioccom.h>

#define	IOP_MAX_MSG_XFERS	3	/* Maximum transfer count per msg */
#define	IOP_MAX_OUTBOUND	256	/* Maximum outbound queue depth */
#define	IOP_MAX_INBOUND		256	/* Maximum inbound queue depth */
#define	IOP_MF_RESERVE		4	/* Frames to reserve for ctl ops */
#define	IOP_MAX_XFER		64*1024	/* Maximum transfer size */
#define	IOP_MAX_MSG_SIZE	160	/* Maximum message frame size */
#define	IOP_MIN_MSG_SIZE	128	/* Minimum size supported by IOP */

struct iop_tidmap {
	u_short	it_tid;
	u_short	it_flags;
	char	it_dvname[16];
};
#define	IT_CONFIGURED	0x02	/* target configured */

struct ioppt_buf {
	void	*ptb_data;	/* pointer to buffer */
	size_t	ptb_datalen;	/* buffer size in bytes */
	int	ptb_out;	/* non-zero if transfer is to IOP */
};

struct ioppt {
	void	*pt_msg;	/* pointer to message buffer */
	size_t	pt_msglen;	/* message buffer size in bytes */
	void	*pt_reply;	/* pointer to reply buffer */
	size_t	pt_replylen;	/* reply buffer size in bytes */
	int	pt_timo;	/* completion timeout in ms */
	int	pt_nbufs;	/* number of transfers */
	struct	ioppt_buf pt_bufs[IOP_MAX_MSG_XFERS]; /* transfers */
};

#define	IOPIOCPT	_IOWR('u', 0, struct ioppt)
#define	IOPIOCGLCT	_IOWR('u', 1, struct iovec)
#define	IOPIOCGSTATUS	_IOWR('u', 2, struct iovec)
#define	IOPIOCRECONFIG	_IO('u', 3)
#define	IOPIOCGTIDMAP	_IOWR('u', 4, struct iovec)

#endif	/* !_I2O_IOPIO_H_ */