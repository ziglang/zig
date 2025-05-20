/*	$NetBSD: ipc.h,v 1.37 2018/06/23 07:23:06 gson Exp $	*/

/*
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department.
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
 *	@(#)ipc.h	8.4 (Berkeley) 2/19/95
 */

/*
 * SVID compatible ipc.h file
 */

#ifndef _SYS_IPC_H_
#define _SYS_IPC_H_

#include <sys/featuretest.h>
#include <sys/types.h>

struct ipc_perm {
	uid_t		uid;	/* user id */
	gid_t		gid;	/* group id */
	uid_t		cuid;	/* creator user id */
	gid_t		cgid;	/* creator group id */
	mode_t		mode;	/* r/w permission */

	/*
	 * These members are private and used only in the internal
	 * implementation of this interface.
	 */
	unsigned short	_seq;	/* sequence # (to generate unique
				   msg/sem/shm id) */
	key_t		_key;	/* user specified msg/sem/shm key */
};

#if defined(_NETBSD_SOURCE)
/* Warning: 64-bit structure padding is needed here */
struct ipc_perm_sysctl {
	uint64_t	_key;
	uid_t		uid;
	gid_t		gid;
	uid_t		cuid;
	gid_t		cgid;
	mode_t		mode;
	int16_t		_seq;
	int16_t		pad;
};
#endif /* _NETBSD_SOURCE */

/* Common access type bits, used with ipcperm(). */
#define	IPC_R		000400	/* read permission */
#define	IPC_W		000200	/* write/alter permission */
#define	IPC_M		010000	/* permission to change control info */

/* X/Open required constants (same values as system 5) */
#define	IPC_CREAT	001000	/* create entry if key does not exist */
#define	IPC_EXCL	002000	/* fail if key exists */
#define	IPC_NOWAIT	004000	/* error if request must wait */

#define	IPC_PRIVATE	(key_t)0 /* private key */

#define	IPC_RMID	0	/* remove identifier */
#define	IPC_SET		1	/* set options */
#define	IPC_STAT	2	/* get options */

/*
 * Macros to convert between ipc ids and array indices or sequence ids.
 * The first of these is used by ipcs(1), and so is defined outside the
 * kernel as well.
 */
#if defined(_NETBSD_SOURCE)
#define	IXSEQ_TO_IPCID(ix,perm)	(((perm._seq) << 16) | (ix & 0xffff))
#endif

#ifdef _KERNEL
#include <sys/sysctl.h>
#define	IPCID_TO_IX(id)		((id) & 0xffff)
#define	IPCID_TO_SEQ(id)	(((id) >> 16) & 0xffff)

struct kauth_cred;
__BEGIN_DECLS
int	ipcperm(struct kauth_cred *, struct ipc_perm *, int);

void	sysvipcinit(void);
void	sysvipcfini(void);
__END_DECLS

/*
 * sysctl helper routine for kern.ipc.sysvipc_info subtree.
 */

#define SYSCTL_FILL_PERM(src, dst) do { \
	(dst)._key = (src)._key; \
	(dst).uid = (src).uid; \
	(dst).gid = (src).gid; \
	(dst).cuid = (src).cuid; \
	(dst).cgid = (src).cgid; \
	(dst).mode = (src).mode; \
	(dst)._seq = (src)._seq; \
} while (/*CONSTCOND*/ 0)

/*
 * Set-up the sysctl routine for COMPAT_50
 */

__BEGIN_DECLS
void sysvipc50_set_compat_sysctl(int (*)(SYSCTLFN_PROTO));
__END_DECLS

#else /* _KERNEL */
__BEGIN_DECLS
key_t	ftok(const char *, int);
__END_DECLS
#endif
#endif /* !_SYS_IPC_H_ */