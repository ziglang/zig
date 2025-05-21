/*	$NetBSD: msgbuf.h,v 1.18 2022/10/26 23:28:43 riastradh Exp $	*/

/*
 * Copyright (c) 1981, 1984, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)msgbuf.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _SYS_MSGBUF_H_
#define _SYS_MSGBUF_H_

struct	kern_msgbuf {
#define	MSG_MAGIC	0x063061
	long	msg_magic;
	long	msg_bufx;		/* write pointer */
	long	msg_bufr;		/* read pointer */
	long	msg_bufs;		/* real msg_bufc size (bytes) */
	char	msg_bufc[1];		/* buffer */
};

#ifdef _KERNEL
extern int	msgbufmapped;		/* is the message buffer mapped */
extern int	msgbufenabled;		/* is logging to the buffer enabled */
extern struct	kern_msgbuf *msgbufp;	/* the mapped buffer, itself. */
extern int	log_open;		/* is /dev/klog open? */

void	initmsgbuf(void *, size_t);
void	loginit(void);
void	logputchar(int);

static __inline int
logenabled(const struct kern_msgbuf *mbp)
{
	return msgbufenabled && mbp->msg_magic == MSG_MAGIC;
}
#endif

#endif /* !_SYS_MSGBUF_H_ */