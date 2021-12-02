/*
 * Copyright (c) 2000-2002 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*	$NetBSD: shm.h,v 1.15 1994/06/29 06:45:17 cgd Exp $	*/

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
#include <sys/_types.h>

/*
 * [XSI]	All of the symbols from <sys/ipc.h> SHALL be defined
 *		when this header is included
 */
#include <sys/ipc.h>

/*
 * [XSI] The pid_t, time_t, key_t, and size_t types shall be defined as
 * described in <sys/types.h>.
 *
 * NOTE:	The definition of the key_t type is implicit from the
 *		inclusion of <sys/ipc.h>
 */
#include <sys/_types/_pid_t.h>
#include <sys/_types/_time_t.h>
#include <sys/_types/_size_t.h>

/*
 * [XSI] The unsigned integer type used for the number of current attaches
 * that MUST be able to store values at least as large as a type unsigned
 * short.
 */
typedef unsigned short  shmatt_t;


/*
 * Possible flag values which may be OR'ed into the third argument to
 * shmat()
 */
#define SHM_RDONLY      010000  /* [XSI] Attach read-only (else read-write) */
#define SHM_RND         020000  /* [XSI] Round attach address to SHMLBA */

/*
 * This value is symbolic, and generally not expected to be sed by user
 * programs directly, although such ise is permitted by the standard.  Its
 * value in our implementation is equal to the number of bytes per page.
 *
 * NOTE:	We DO NOT obtain this value from the appropriate system
 *		headers at this time, to avoid the resulting namespace
 *		pollution, which is why we discourages its use.
 */
#define SHMLBA      4096        /* [XSI] Segment low boundary address multiple*/

/* "official" access mode definitions; somewhat braindead since you have
 *  to specify (SHM_* >> 3) for group and (SHM_* >> 6) for world permissions */
#define SHM_R       (IPC_R)
#define SHM_W       (IPC_W)

#pragma pack(4)

/*
 * Technically, we should force all code references to the new structure
 * definition, not in just the standards conformance case, and leave the
 * legacy interface there for binary compatibility only.  Currently, we
 * are only forcing this for programs requesting standards conformance.
 */
#if __DARWIN_UNIX03 || defined(KERNEL)
/*
 * Structure used internally.
 *
 * This structure is exposed because standards dictate that it is used as
 * the third argment to shmctl().
 *
 * NOTE:	The field shm_internal is not meaningful in user space,
 *		and must not be used there.
 */
#if (defined(_POSIX_C_SOURCE) && !defined(_DARWIN_C_SOURCE))
struct shmid_ds
#else
#define shmid_ds        __shmid_ds_new
struct __shmid_ds_new
#endif
{
	struct __ipc_perm_new shm_perm; /* [XSI] Operation permission value */
	size_t          shm_segsz;      /* [XSI] Size of segment in bytes */
	pid_t           shm_lpid;       /* [XSI] PID of last shared memory op */
	pid_t           shm_cpid;       /* [XSI] PID of creator */
	shmatt_t        shm_nattch;     /* [XSI] Number of current attaches */
	time_t          shm_atime;      /* [XSI] Time of last shmat() */
	time_t          shm_dtime;      /* [XSI] Time of last shmdt() */
	time_t          shm_ctime;      /* [XSI] Time of last shmctl() change */
	void            *shm_internal;  /* reserved for kernel use */
};
#else   /* !__DARWIN_UNIX03 */
#define shmid_ds        __shmid_ds_old
#endif  /* !__DARWIN_UNIX03 */

#if !__DARWIN_UNIX03
struct __shmid_ds_old {
	struct __ipc_perm_old shm_perm; /* [XSI] Operation permission value */
	size_t          shm_segsz;      /* [XSI] Size of segment in bytes */
	pid_t           shm_lpid;       /* [XSI] PID of last shared memory op */
	pid_t           shm_cpid;       /* [XSI] PID of creator */
	shmatt_t        shm_nattch;     /* [XSI] Number of current attaches */
	time_t          shm_atime;      /* [XSI] Time of last shmat() */
	time_t          shm_dtime;      /* [XSI] Time of last shmdt() */
	time_t          shm_ctime;      /* [XSI] Time of last shmctl() change */
	void            *shm_internal;  /* reserved for kernel use */
};
#endif  /* !__DARWIN_UNIX03 */

#pragma pack()


__BEGIN_DECLS
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
int     shmsys(int, ...);
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
void    *shmat(int, const void *, int);
int     shmctl(int, int, struct shmid_ds *) __DARWIN_ALIAS(shmctl);
int     shmdt(const void *);
int     shmget(key_t, size_t, int);
__END_DECLS


#endif /* !_SYS_SHM_H_ */