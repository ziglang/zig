/*	$NetBSD: msg.h,v 1.28 2019/08/07 00:38:02 pgoyette Exp $	*/

/*-
 * Copyright (c) 1999, 2007 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center, and by Andrew Doran.
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

/*
 * SVID compatible msg.h file
 *
 * Author:  Daniel Boulet
 *
 * Copyright 1993 Daniel Boulet and RTMX Inc.
 *
 * This system call was implemented by Daniel Boulet under contract from RTMX.
 *
 * Redistribution and use in source forms, with and without modification,
 * are permitted provided that this entire comment appears intact.
 *
 * Redistribution in binary form may occur without any restrictions.
 * Obviously, it would be nice if you gave credit where credit is due
 * but requiring it would be too onerous.
 *
 * This software is provided ``AS IS'' without any warranties of any kind.
 */

#ifndef _SYS_MSG_H_
#define _SYS_MSG_H_

#include <sys/featuretest.h>
#include <sys/ipc.h>
#ifdef _KERNEL
#include <sys/condvar.h>
#include <sys/mutex.h>
#endif

#ifdef _KERNEL
struct __msg {
	struct	__msg *msg_next; /* next msg in the chain */
	long	msg_type;	/* type of this message */
    				/* >0 -> type of this message */
    				/* 0 -> free header */
	u_short	msg_ts;		/* size of this message */
	short	msg_spot;	/* location of start of msg in buffer */
};
#endif /* _KERNEL */

#define MSG_NOERROR	010000		/* don't complain about too long msgs */

typedef unsigned long	msgqnum_t;
typedef size_t		msglen_t;

struct msqid_ds {
	struct ipc_perm	msg_perm;	/* operation permission strucure */
	msgqnum_t	msg_qnum;	/* number of messages in the queue */
	msglen_t	msg_qbytes;	/* max # of bytes in the queue */
	pid_t		msg_lspid;	/* process ID of last msgsend() */
	pid_t		msg_lrpid;	/* process ID of last msgrcv() */
	time_t		msg_stime;	/* time of last msgsend() */
	time_t		msg_rtime;	/* time of last msgrcv() */
	time_t		msg_ctime;	/* time of last change */

	/*
	 * These members are private and used only in the internal
	 * implementation of this interface.
	 */
	struct __msg	*_msg_first;	/* first message in the queue */
	struct __msg	*_msg_last;	/* last message in the queue */
	msglen_t	_msg_cbytes;	/* # of bytes currently in queue */
};

#if defined(_NETBSD_SOURCE)
/*
 * Based on the configuration parameters described in an SVR2 (yes, two)
 * config(1m) man page.
 *
 * Each message is broken up and stored in segments that are msgssz bytes
 * long.  For efficiency reasons, this should be a power of two.  Also,
 * it doesn't make sense if it is less than 8 or greater than about 256.
 * Consequently, msginit in kern/sysv_msg.c checks that msgssz is a power of
 * two between 8 and 1024 inclusive (and panic's if it isn't).
 */
struct msginfo {
	int32_t	msgmax;		/* max chars in a message */
	int32_t	msgmni;		/* max message queue identifiers */
	int32_t	msgmnb;		/* max chars in a queue */
	int32_t	msgtql;		/* max messages in system */
	int32_t	msgssz;		/* size of a message segment
				   (see notes above) */
	int32_t	msgseg;		/* number of message segments */
};

/* Warning: 64-bit structure padding is needed here */
struct msgid_ds_sysctl {
	struct		ipc_perm_sysctl msg_perm;
	uint64_t	msg_qnum;
	uint64_t	msg_qbytes;
	uint64_t	_msg_cbytes;
	pid_t		msg_lspid;
	pid_t		msg_lrpid;
	time_t		msg_stime;
	time_t		msg_rtime;
	time_t		msg_ctime;
	int32_t		pad;
};
struct msg_sysctl_info {
	struct	msginfo msginfo;
	struct	msgid_ds_sysctl msgids[1];
};
#endif /* !_POSIX_C_SOURCE && !_XOPEN_SOURCE */

#ifdef _KERNEL

#ifndef MSGSSZ
#define MSGSSZ	8		/* Each segment must be 2^N long */
#endif
#ifndef MSGSEG
#define MSGSEG	2048		/* must be less than 32767 */
#endif
#undef MSGMAX			/* ALWAYS compute MGSMAX! */
#define MSGMAX	(MSGSSZ*MSGSEG)
#ifndef MSGMNB
#define MSGMNB	2048		/* max # of bytes in a queue */
#endif
#ifndef MSGMNI
#define MSGMNI	40
#endif
#ifndef MSGTQL
#define MSGTQL	40
#endif

/*
 * macros to convert between msqid_ds's and msqid's.
 */
#define MSQID(ix,ds)	((ix) & 0xffff | (((ds).msg_perm._seq << 16) & 0xffff0000))
#define MSQID_IX(id)	((id) & 0xffff)
#define MSQID_SEQ(id)	(((id) >> 16) & 0xffff)

/*
 * Stuff allocated in machdep.h
 */
struct msgmap {
	short	next;		/* next segment in buffer */
    				/* -1 -> available */
    				/* 0..(MSGSEG-1) -> index of next segment */
};

typedef struct kmsq {
	struct msqid_ds msq_u;
	kcondvar_t	msq_cv;
} kmsq_t;

extern struct msginfo msginfo;
extern kmsq_t	*msqs;		/* MSGMNI queues */
extern kmutex_t	msgmutex;

#define MSG_LOCKED	01000	/* Is this msqid_ds locked? */

#define SYSCTL_FILL_MSG(src, dst) do { \
	SYSCTL_FILL_PERM((src).msg_perm, (dst).msg_perm); \
	(dst).msg_qnum = (src).msg_qnum; \
	(dst).msg_qbytes = (src).msg_qbytes; \
	(dst)._msg_cbytes = (src)._msg_cbytes; \
	(dst).msg_lspid = (src).msg_lspid; \
	(dst).msg_lrpid = (src).msg_lrpid; \
	(dst).msg_stime = (src).msg_stime; \
	(dst).msg_rtime = (src).msg_rtime; \
	(dst).msg_ctime = (src).msg_ctime; \
} while (/*CONSTCOND*/ 0)

#endif /* _KERNEL */

#ifndef _KERNEL
#include <sys/cdefs.h>

__BEGIN_DECLS
int	msgctl(int, int, struct msqid_ds *) __RENAME(__msgctl50);
int	msgget(key_t, int);
int	msgsnd(int, const void *, size_t, int);
ssize_t	msgrcv(int, void *, size_t, long, int);
__END_DECLS
#else
#include <sys/systm.h>

struct proc;

int	msginit(void);
int	msgfini(void);
int	msgctl1(struct lwp *, int, int, struct msqid_ds *);
int	msgsnd1(struct lwp *, int, const char *, size_t, int, size_t,
    copyin_t);
int	msgrcv1(struct lwp *, int, char *, size_t, long, int, size_t,
    copyout_t, register_t *);
#endif /* !_KERNEL */

#endif /* !_SYS_MSG_H_ */