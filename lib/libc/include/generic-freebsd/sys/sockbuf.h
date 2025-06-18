/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1990, 1993
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
 *	@(#)socketvar.h	8.3 (Berkeley) 2/19/95
 */
#ifndef _SYS_SOCKBUF_H_
#define _SYS_SOCKBUF_H_

/*
 * Constants for sb_flags field of struct sockbuf/xsockbuf.
 */
#define	SB_TLS_RX	0x01		/* using KTLS on RX */
#define	SB_TLS_RX_RUNNING 0x02		/* KTLS RX operation running */
#define	SB_WAIT		0x04		/* someone is waiting for data/space */
#define	SB_SEL		0x08		/* someone is selecting */
#define	SB_ASYNC	0x10		/* ASYNC I/O, need signals */
#define	SB_UPCALL	0x20		/* someone wants an upcall */
#define	SB_NOINTR	0x40		/* operations not interruptible */
#define	SB_AIO		0x80		/* AIO operations queued */
#define	SB_KNOTE	0x100		/* kernel note attached */
#define	SB_NOCOALESCE	0x200		/* don't coalesce new data into existing mbufs */
#define	SB_IN_TOE	0x400		/* socket buffer is in the middle of an operation */
#define	SB_AUTOSIZE	0x800		/* automatically size socket buffer */
#define	SB_STOP		0x1000		/* backpressure indicator */
#define	SB_AIO_RUNNING	0x2000		/* AIO operation running */
#define	SB_SPLICED	0x4000		/* socket buffer is spliced;
					   previously used for SB_TLS_IFNET */
#define	SB_TLS_RX_RESYNC 0x8000		/* KTLS RX lost HW sync */

#define	SBS_CANTSENDMORE	0x0010	/* can't send more data to peer */
#define	SBS_CANTRCVMORE		0x0020	/* can't receive more data from peer */
#define	SBS_RCVATMARK		0x0040	/* at mark on input */

#if defined(_KERNEL) || defined(_WANT_SOCKET)
#include <sys/_lock.h>
#include <sys/_mutex.h>
#include <sys/_sx.h>
#include <sys/_task.h>

#define	SB_MAX		(2*1024*1024)	/* default for max chars in sockbuf */

struct ktls_session;
struct mbuf;
struct sockaddr;
struct socket;
struct sockopt;
struct thread;
struct selinfo;

/*
 * Socket buffer
 *
 * A buffer starts with the fields that are accessed by I/O multiplexing
 * APIs like select(2), kevent(2) or AIO and thus are shared between different
 * buffer implementations.  They are protected by the SOCK_RECVBUF_LOCK()
 * or SOCK_SENDBUF_LOCK() of the owning socket.
 *
 * XXX: sb_acc, sb_ccc and sb_mbcnt shall become implementation specific
 * methods.
 *
 * Protocol specific implementations follow in a union.
 */
struct sockbuf {
	struct	selinfo *sb_sel;	/* process selecting read/write */
	short	sb_state;		/* socket state on sockbuf */
	short	sb_flags;		/* flags, see above */
	u_int	sb_acc;			/* available chars in buffer */
	u_int	sb_ccc;			/* claimed chars in buffer */
	u_int	sb_mbcnt;		/* chars of mbufs used */
	u_int	sb_ctl;			/* non-data chars in buffer */
	u_int	sb_hiwat;		/* max actual char count */
	u_int	sb_lowat;		/* low water mark */
	u_int	sb_mbmax;		/* max chars of mbufs to use */
	sbintime_t sb_timeo;		/* timeout for read/write */
	int	(*sb_upcall)(struct socket *, void *, int);
	void	*sb_upcallarg;
	TAILQ_HEAD(, kaiocb) sb_aiojobq;	/* pending AIO ops */
	struct	task sb_aiotask;		/* AIO task */
	union {
		/*
		 * Classic BSD one-size-fits-all socket buffer, capable of
		 * doing streams and datagrams. The stream part is able
		 * to perform special features:
		 * - not ready data (sendfile)
		 * - TLS
		 */
		struct {
			/* compat: sockbuf lock pointer */
			struct	mtx *sb_mtx;
			/* first and last mbufs in the chain */
			struct	mbuf *sb_mb;
			struct	mbuf *sb_mbtail;
			/* first mbuf of last record in socket buffer */
			struct	mbuf *sb_lastrecord;
			/* pointer to data to send next (TCP */
			struct	mbuf *sb_sndptr;
			/* pointer to first not ready buffer */
			struct	mbuf *sb_fnrdy;
			/* byte offset of ptr into chain, used with sb_sndptr */
			u_int	sb_sndptroff;
			/* TLS */
			u_int	sb_tlscc;	/* TLS chain characters */
			u_int	sb_tlsdcc;	/* characters being decrypted */
			struct	mbuf *sb_mtls;	/*  TLS mbuf chain */
			struct	mbuf *sb_mtlstail; /* last mbuf in TLS chain */
			uint64_t sb_tls_seqno;	/* TLS seqno */
			/* TLS state, locked by sockbuf and sock I/O mutexes. */
			struct	ktls_session *sb_tls_info;
		};
		/*
		 * PF_UNIX/SOCK_DGRAM
		 *
		 * Local protocol, thus we should buffer on the receive side
		 * only.  However, in one to many configuration we don't want
		 * a single receive buffer to be shared.  So we would link
		 * send buffers onto receive buffer.  All the fields are locked
		 * by the receive buffer lock.
		 */
		struct {
			/*
			 * For receive buffer: own queue of this buffer for
			 * unconnected sends.  For send buffer: queue lended
			 * to the peer receive buffer, to isolate ourselves
			 * from other senders.
			 */
			STAILQ_HEAD(, mbuf)	uxdg_mb;
			/* For receive buffer: datagram seen via MSG_PEEK. */
			struct mbuf		*uxdg_peeked;
			/*
			 * For receive buffer: queue of send buffers of
			 * connected peers.  For send buffer: linkage on
			 * connected peer receive buffer queue.
			 */
			union {
				TAILQ_HEAD(, sockbuf)	uxdg_conns;
				TAILQ_ENTRY(sockbuf)	uxdg_clist;
			};
			/* Counters for this buffer uxdg_mb chain + peeked. */
			u_int uxdg_cc;
			u_int uxdg_ctl;
			u_int uxdg_mbcnt;
		};
	};
};

#endif	/* defined(_KERNEL) || defined(_WANT_SOCKET) */
#ifdef _KERNEL

/* 'which' values for KPIs that operate on one buffer of a socket. */
typedef enum { SO_RCV, SO_SND } sb_which;

/*
 * Per-socket buffer mutex used to protect most fields in the socket buffer.
 * These make use of the mutex pointer embedded in struct sockbuf, which
 * currently just references mutexes in the containing socket.  The
 * SOCK_SENDBUF_LOCK() etc. macros can be used instead of or in combination with
 * these locking macros.
 */
#define	SOCKBUF_MTX(_sb)		((_sb)->sb_mtx)
#define	SOCKBUF_LOCK(_sb)		mtx_lock(SOCKBUF_MTX(_sb))
#define	SOCKBUF_OWNED(_sb)		mtx_owned(SOCKBUF_MTX(_sb))
#define	SOCKBUF_UNLOCK(_sb)		mtx_unlock(SOCKBUF_MTX(_sb))
#define	SOCKBUF_LOCK_ASSERT(_sb)	mtx_assert(SOCKBUF_MTX(_sb), MA_OWNED)
#define	SOCKBUF_UNLOCK_ASSERT(_sb)	mtx_assert(SOCKBUF_MTX(_sb), MA_NOTOWNED)

/*
 * Socket buffer private mbuf(9) flags.
 */
#define	M_NOTREADY	M_PROTO1	/* m_data not populated yet */
#define	M_BLOCKED	M_PROTO2	/* M_NOTREADY in front of m */
#define	M_NOTAVAIL	(M_NOTREADY | M_BLOCKED)

void	sbappend(struct sockbuf *sb, struct mbuf *m, int flags);
void	sbappend_locked(struct sockbuf *sb, struct mbuf *m, int flags);
void	sbappendstream(struct sockbuf *sb, struct mbuf *m, int flags);
void	sbappendstream_locked(struct sockbuf *sb, struct mbuf *m, int flags);
int	sbappendaddr(struct sockbuf *sb, const struct sockaddr *asa,
	    struct mbuf *m0, struct mbuf *control);
int	sbappendaddr_locked(struct sockbuf *sb, const struct sockaddr *asa,
	    struct mbuf *m0, struct mbuf *control);
int	sbappendaddr_nospacecheck_locked(struct sockbuf *sb,
	    const struct sockaddr *asa, struct mbuf *m0, struct mbuf *control);
void	sbappendcontrol(struct sockbuf *sb, struct mbuf *m0,
	    struct mbuf *control, int flags);
void	sbappendcontrol_locked(struct sockbuf *sb, struct mbuf *m0,
	    struct mbuf *control, int flags);
void	sbappendrecord(struct sockbuf *sb, struct mbuf *m0);
void	sbappendrecord_locked(struct sockbuf *sb, struct mbuf *m0);
void	sbcompress(struct sockbuf *sb, struct mbuf *m, struct mbuf *n);
struct mbuf *
	sbcreatecontrol(const void *p, u_int size, int type, int level,
	    int wait);
void	sbdestroy(struct socket *, sb_which);
void	sbdrop(struct sockbuf *sb, int len);
void	sbdrop_locked(struct sockbuf *sb, int len);
struct mbuf *
	sbcut_locked(struct sockbuf *sb, int len);
void	sbdroprecord(struct sockbuf *sb);
void	sbdroprecord_locked(struct sockbuf *sb);
void	sbflush(struct sockbuf *sb);
void	sbflush_locked(struct sockbuf *sb);
void	sbrelease(struct socket *, sb_which);
void	sbrelease_locked(struct socket *, sb_which);
int	sbsetopt(struct socket *so, struct sockopt *);
bool	sbreserve_locked(struct socket *so, sb_which which, u_long cc,
	    struct thread *td);
bool	sbreserve_locked_limit(struct socket *so, sb_which which, u_long cc,
	    u_long buf_max, struct thread *td);
void	sbsndptr_adv(struct sockbuf *sb, struct mbuf *mb, u_int len);
struct mbuf *
	sbsndptr_noadv(struct sockbuf *sb, u_int off, u_int *moff);
struct mbuf *
	sbsndmbuf(struct sockbuf *sb, u_int off, u_int *moff);
int	sbwait(struct socket *, sb_which);
void	sballoc(struct sockbuf *, struct mbuf *);
void	sbfree(struct sockbuf *, struct mbuf *);
void	sballoc_ktls_rx(struct sockbuf *sb, struct mbuf *m);
void	sbfree_ktls_rx(struct sockbuf *sb, struct mbuf *m);
int	sbready(struct sockbuf *, struct mbuf *, int);

/*
 * Return how much data is available to be taken out of socket
 * buffer right now.
 */
static inline u_int
sbavail(struct sockbuf *sb)
{

#if 0
	SOCKBUF_LOCK_ASSERT(sb);
#endif
	return (sb->sb_acc);
}

/*
 * Return how much data sits there in the socket buffer
 * It might be that some data is not yet ready to be read.
 */
static inline u_int
sbused(struct sockbuf *sb)
{

#if 0
	SOCKBUF_LOCK_ASSERT(sb);
#endif
	return (sb->sb_ccc);
}

/*
 * How much space is there in a socket buffer (so->so_snd or so->so_rcv)?
 * This is problematical if the fields are unsigned, as the space might
 * still be negative (ccc > hiwat or mbcnt > mbmax).
 */
static inline long
sbspace(struct sockbuf *sb)
{
	int bleft, mleft;		/* size should match sockbuf fields */

#if 0
	SOCKBUF_LOCK_ASSERT(sb);
#endif

	if (sb->sb_flags & SB_STOP)
		return(0);

	bleft = sb->sb_hiwat - sb->sb_ccc;
	mleft = sb->sb_mbmax - sb->sb_mbcnt;

	return ((bleft < mleft) ? bleft : mleft);
}

#define SB_EMPTY_FIXUP(sb) do {						\
	if ((sb)->sb_mb == NULL) {					\
		(sb)->sb_mbtail = NULL;					\
		(sb)->sb_lastrecord = NULL;				\
	}								\
} while (/*CONSTCOND*/0)

#ifdef SOCKBUF_DEBUG
void	sblastrecordchk(struct sockbuf *, const char *, int);
void	sblastmbufchk(struct sockbuf *, const char *, int);
void	sbcheck(struct sockbuf *, const char *, int);
#define	SBLASTRECORDCHK(sb)	sblastrecordchk((sb), __FILE__, __LINE__)
#define	SBLASTMBUFCHK(sb)	sblastmbufchk((sb), __FILE__, __LINE__)
#define	SBCHECK(sb)		sbcheck((sb), __FILE__, __LINE__)
#else
#define	SBLASTRECORDCHK(sb)	do {} while (0)
#define	SBLASTMBUFCHK(sb)	do {} while (0)
#define	SBCHECK(sb)		do {} while (0)
#endif /* SOCKBUF_DEBUG */

#endif /* _KERNEL */

#endif /* _SYS_SOCKBUF_H_ */