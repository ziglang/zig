/* $NetBSD: pipe.h,v 1.38 2021/01/25 19:21:11 dholland Exp $ */

/*
 * Copyright (c) 1996 John S. Dyson
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice immediately at the beginning of the file, without modification,
 *    this list of conditions, and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Absolutely no warranty of function or purpose is made by the author
 *    John S. Dyson.
 * 4. This work was done expressly for inclusion into FreeBSD.  Other use
 *    is allowed if this notation is included.
 * 5. Modifications may be freely made to this file if the above conditions
 *    are met.
 *
 * $FreeBSD: src/sys/sys/pipe.h,v 1.18 2002/02/27 07:35:59 alfred Exp $
 */

#ifndef _SYS_PIPE_H_
#define _SYS_PIPE_H_

#include <sys/selinfo.h>		/* for struct selinfo */
#include <sys/time.h>			/* for struct timespec */

#include <uvm/uvm_extern.h>

/*
 * Pipe buffer size, keep moderate in value, pipes take kva space.
 */
#ifndef PIPE_SIZE
#define PIPE_SIZE	16384
#endif

#ifndef BIG_PIPE_SIZE
#define BIG_PIPE_SIZE	(4*PIPE_SIZE)
#endif

/*
 * Maximum size of transfer for direct write transfer. If the amount
 * of data in buffer is larger, it would be transferred in chunks of this
 * size.
 */
#ifndef PIPE_DIRECT_CHUNK
#define PIPE_DIRECT_CHUNK	(1*1024*1024)
#endif

/*
 * PIPE_MINDIRECT MUST be smaller than PIPE_SIZE and MUST be bigger
 * than PIPE_BUF.
 */
#ifndef PIPE_MINDIRECT
#define PIPE_MINDIRECT	8192
#endif

/*
 * Pipe buffer information.
 * Separate in, out, cnt are used to simplify calculations.
 * Buffered write is active when the buffer.cnt field is set.
 */
struct pipebuf {
	size_t	cnt;		/* number of chars currently in buffer */
	u_int	in;		/* in pointer */
	u_int	out;		/* out pointer */
	size_t	size;		/* size of buffer */
	void *	buffer;		/* kva of buffer */
};

/*
 * Bits in pipe_state.
 */
#define PIPE_ASYNC	0x001	/* Async I/O */
#define PIPE_EOF	0x010	/* Pipe is in EOF condition */
#define PIPE_SIGNALR	0x020	/* Do selwakeup() on read(2) */
#define	PIPE_LOCKFL	0x100	/* Process has exclusive access to
				   pointers/data. */
/*	unused  	0x200	*/
#define	PIPE_RESTART	0x400	/* Return ERESTART to blocked syscalls */

/*
 * Per-pipe data structure.
 * Two of these are linked together to produce bi-directional pipes.
 */
struct pipe {
	kmutex_t *pipe_lock;		/* pipe mutex */
	kcondvar_t pipe_rcv;		/* cv for readers */
	kcondvar_t pipe_wcv;		/* cv for writers */
	kcondvar_t pipe_draincv;	/* cv for close */
	kcondvar_t pipe_lkcv;		/* locking */
	struct	pipebuf pipe_buffer;	/* data storage */
	struct	selinfo pipe_sel;	/* for compat with select */
	struct	timespec pipe_atime;	/* time of last access */
	struct	timespec pipe_mtime;	/* time of last modify */
	struct	timespec pipe_btime;	/* time of creation */
	pid_t	pipe_pgid;		/* process group for sigio */
	u_int	pipe_waiters;		/* number of waiters pending */
	struct	pipe *pipe_peer;	/* link with other direction */
	u_int	pipe_state;		/* pipe status info */
	int	pipe_busy;		/* busy flag, to handle rundown */
	vaddr_t	pipe_kmem;		/* preallocated PIPE_SIZE buffer */
};

/*
 * KERN_PIPE subtypes
 */
#define	KERN_PIPE_MAXKVASZ		1	/* maximum kva size (obsolete) */
#define	KERN_PIPE_LIMITKVA		2	/* limit kva for laons (obsolete) */
#define	KERN_PIPE_MAXBIGPIPES		3	/* maximum # of "big" pipes */
#define	KERN_PIPE_NBIGPIPES		4	/* current number of "big" p. */
#define	KERN_PIPE_KVASIZE		5	/* current pipe kva size */

#ifdef _KERNEL
int	sysctl_dopipe(int *, u_int, void *, size_t *, void *, size_t);
void	pipe_init(void);
#endif /* _KERNEL */

#endif /* !_SYS_PIPE_H_ */