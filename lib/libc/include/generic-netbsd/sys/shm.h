/*	$NetBSD: shm.h,v 1.55 2021/08/17 22:00:32 andvar Exp $	*/

/*-
 * Copyright (c) 1999 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center.
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
 * Copyright (c) 1994 Adam Glass
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Adam Glass.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
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
 * As defined+described in "X/Open System Interfaces and Headers"
 *                         Issue 4, p. XXX
 */

#ifndef _SYS_SHM_H_
#define _SYS_SHM_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>

#include <sys/ipc.h>

#define	SHM_RDONLY	010000	/* Attach read-only (else read-write) */
#define	SHM_RND		020000	/* Round attach address to SHMLBA */
#ifdef _KERNEL
#define _SHM_RMLINGER	040000	/* Attach even if segment removed */
#endif

/* Segment low boundary address multiple */
#if defined(_KERNEL) || defined(_STANDALONE) || defined(_MODULE)
#define	SHMLBA		PAGE_SIZE
#else
/*
 * SHMLBA uses libc's internal __sysconf() to retrieve the machine's
 * page size. The value of _SC_PAGESIZE is 28 -- we hard code it so we do not
 * need to include unistd.h
 */
__BEGIN_DECLS
long __sysconf(int);
__END_DECLS
#define	SHMLBA		(__sysconf(28))
#endif

typedef unsigned int	shmatt_t;

struct shmid_ds {
	struct ipc_perm	shm_perm;	/* operation permission structure */
	size_t		shm_segsz;	/* size of segment in bytes */
	pid_t		shm_lpid;	/* process ID of last shm operation */
	pid_t		shm_cpid;	/* process ID of creator */
	shmatt_t	shm_nattch;	/* number of current attaches */
	time_t		shm_atime;	/* time of last shmat() */
	time_t		shm_dtime;	/* time of last shmdt() */
	time_t		shm_ctime;	/* time of last change by shmctl() */

	/*
	 * These members are private and used only in the internal
	 * implementation of this interface.
	 */
	void		*_shm_internal;
};

#if defined(_NETBSD_SOURCE)
/*
 * Some systems (e.g. HP-UX) take these as the second (cmd) arg to shmctl().
 */
#define	SHM_LOCK	3	/* Lock segment in memory. */
#define	SHM_UNLOCK	4	/* Unlock a segment locked by SHM_LOCK. */
#endif /* _NETBSD_SOURCE */

#if defined(_NETBSD_SOURCE)
/*
 * Permission definitions used in shmflag arguments to shmat(2) and shmget(2).
 * Provided for source compatibility only; do not use in new code!
 */
#define	SHM_R		IPC_R	/* S_IRUSR, R for owner */
#define	SHM_W		IPC_W	/* S_IWUSR, W for owner */

/*
 * System 5 style catch-all structure for shared memory constants that
 * might be of interest to user programs.  Do we really want/need this?
 */
struct shminfo {
	uint64_t	shmmax;	/* max shared memory segment size (bytes) */
	uint32_t	shmmin;	/* min shared memory segment size (bytes) */
	uint32_t	shmmni;	/* max number of shared memory identifiers */
	uint32_t	shmseg;	/* max shared memory segments per process */
	uint32_t	shmall;	/* max amount of shared memory (pages) */
};

/* Warning: 64-bit structure padding is needed here */
struct shmid_ds_sysctl {
	struct		ipc_perm_sysctl shm_perm;
	uint64_t	shm_segsz;
	pid_t		shm_lpid;
	pid_t		shm_cpid;
	time_t		shm_atime;
	time_t		shm_dtime;
	time_t		shm_ctime;
	uint32_t	shm_nattch;
};
struct shm_sysctl_info {
	struct	shminfo shminfo;
	struct	shmid_ds_sysctl shmids[1];
};
#endif /* _NETBSD_SOURCE */

#ifdef _KERNEL
extern struct shminfo shminfo;
extern struct shmid_ds *shmsegs;
extern int shm_nused;

#define	SHMSEG_FREE		0x0200
#define	SHMSEG_REMOVED		0x0400
#define	SHMSEG_ALLOCATED	0x0800
#define	SHMSEG_WANTED		0x1000
#define	SHMSEG_RMLINGER		0x2000
#define	SHMSEG_WIRED		0x4000

struct vmspace;

int	shminit(void);
int	shmfini(void);
void	shmfork(struct vmspace *, struct vmspace *);
void	shmexit(struct vmspace *);
int	shmctl1(struct lwp *, int, int, struct shmid_ds *);

int	shm_find_segment_perm_by_index(int, struct ipc_perm *);

extern void (*uvm_shmexit)(struct vmspace *);
extern void (*uvm_shmfork)(struct vmspace *, struct vmspace *);

#define SYSCTL_FILL_SHM(src, dst) do { \
	SYSCTL_FILL_PERM((src).shm_perm, (dst).shm_perm); \
	(dst).shm_segsz = (src).shm_segsz; \
	(dst).shm_lpid = (src).shm_lpid; \
	(dst).shm_cpid = (src).shm_cpid; \
	(dst).shm_atime = (src).shm_atime; \
	(dst).shm_dtime = (src).shm_dtime; \
	(dst).shm_ctime = (src).shm_ctime; \
	(dst).shm_nattch = (src).shm_nattch; \
} while (/*CONSTCOND*/ 0)

#else /* !_KERNEL */

__BEGIN_DECLS
void	*shmat(int, const void *, int);
int	shmctl(int, int, struct shmid_ds *) __RENAME(__shmctl50);
int	shmdt(const void *);
int	shmget(key_t, size_t, int);
__END_DECLS

#endif /* !_KERNEL */

#endif /* !_SYS_SHM_H_ */