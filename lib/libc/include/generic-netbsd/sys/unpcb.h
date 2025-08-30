/*	$NetBSD: unpcb.h,v 1.18 2016/04/06 19:45:46 roy Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1989, 1993
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
 *	@(#)unpcb.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _SYS_UNPCB_H_
#define _SYS_UNPCB_H_

#include <sys/un.h>
#include <sys/mutex.h>

/*
 * Protocol control block for an active
 * instance of a UNIX internal protocol.
 *
 * A socket may be associated with an vnode in the
 * file system.  If so, the unp_vnode pointer holds
 * a reference count to this vnode, which should be irele'd
 * when the socket goes away.
 *
 * A socket may be connected to another socket, in which
 * case the control block of the socket to which it is connected
 * is given by unp_conn.
 *
 * A socket may be referenced by a number of sockets (e.g. several
 * sockets may be connected to a datagram socket.)  These sockets
 * are in a linked list starting with unp_refs, linked through
 * unp_nextref and null-terminated.  Note that a socket may be referenced
 * by a number of other sockets and may also reference a socket (not
 * necessarily one which is referencing it).  This generates
 * the need for unp_refs and unp_nextref to be separate fields.
 *
 * Stream sockets keep copies of receive sockbuf sb_cc and sb_mbcnt
 * so that changes in the sockbuf may be computed to modify
 * back pressure on the sender accordingly.
 *
 * The unp_ctime holds the creation time of the socket: it might be part of
 * a socketpair created by pipe(2), and POSIX requires pipe(2) to initialize
 * a stat structure's st_[acm]time members with the pipe's creation time.
 * N.B.: updating st_[am]time when reading/writing the pipe is not required,
 *       so we just use a single timespec and do not implement that.
 */
struct	unpcb {
	struct	socket *unp_socket;	/* pointer back to socket */
	struct	vnode *unp_vnode;	/* if associated with file */
	ino_t	unp_ino;		/* fake inode number */
	struct	unpcb *unp_conn;	/* control block of connected socket */
	struct	unpcb *unp_refs;	/* referencing socket linked list */
	struct 	unpcb *unp_nextref;	/* link in unp_refs list */
	struct	sockaddr_un *unp_addr;	/* bound address of socket */
	kmutex_t *unp_streamlock;	/* lock for est. stream connections */
	size_t	unp_addrlen;		/* size of socket address */
	int	unp_cc;			/* copy of rcv.sb_cc */
	int	unp_mbcnt;		/* copy of rcv.sb_mbcnt */
	struct	timespec unp_ctime;	/* holds creation time */
	int	unp_flags;		/* misc flags; see below*/
	struct	unpcbid unp_connid; 	/* pid and eids of peer */
};

/*
 * Flags in unp_flags.
 *
 * UNP_EIDSVALID - indicates that the unp_connid member is filled in
 * and is really the effective ids of the connected peer.  This is used
 * to determine whether the contents should be sent to the user or
 * not.
 *
 * UNP_EIDSBIND - indicates that the unp_connid member is filled
 * in with data for the listening process.  This is set up in unp_bind() when
 * it fills in unp_connid for later consumption by unp_connect().
 */
#define	UNP_OWANTCRED	0x0001		/* credentials wanted */
#define	UNP_CONNWAIT	0x0002		/* connect blocks until accepted */
#define	UNP_EIDSVALID	0x0004		/* unp_connid contains valid data */
#define	UNP_EIDSBIND	0x0008		/* unp_connid was set by bind() */
#define	UNP_BUSY	0x0010		/* busy connecting or binding */
#define	UNP_WANTCRED	0x0020		/* credentials wanted */

#define	sotounpcb(so)	((struct unpcb *)((so)->so_pcb))

#endif /* !_SYS_UNPCB_H_ */