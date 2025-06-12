/* $NetBSD: xio.h,v 1.6 2015/09/06 06:01:01 dholland Exp $ */

/*
 * Copyright (c) 1995 Charles D. Cranor
 * All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * x i o . h
 *
 * this file defines the software structure we use to ioctl the
 * 753/7053.   this interface isn't set in stone and may (or may not)
 * need adjustment.
 *
 * author: Chuck Cranor <chuck@netbsd>
 */

/*
 * xylogic ioctl interface
 */

#include <sys/ioccom.h>


struct xd_iocmd {
	u_char cmd;	/* in: command number */
	u_char subfn;	/* in: subfunction number */
	u_char errnum;	/* out: error number */
	u_char tries;	/* out: number of tries */
	u_short sectcnt;/* in,out: sector count (hw_spt on read drive param) */
	u_short dlen;	/* in: length of data buffer (good sanity check) */
	u_int block;	/* in: block number */
	void *dptr;	/* in: data buffer to do I/O from */
};

#ifndef DIOSXDCMD
#define DIOSXDCMD _IOWR('x', 101, struct xd_iocmd) /* do xd command */
#endif

#define XD_IOCMD_MAXS 16 /* max number of sectors you can do */
#define XD_IOCMD_HSZ   4 /* size of one header */
#define XD_IOCMD_DMSZ 24 /* defect map size */