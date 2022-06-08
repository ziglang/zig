/*
 * Copyright (c) 2000-2021 Apple Inc. All rights reserved.
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
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1982, 1986, 1991, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)types.h	8.4 (Berkeley) 1/21/94
 */

#ifndef _SYS_TYPES_H_
#define _SYS_TYPES_H_

#include <sys/appleapiopts.h>

#ifndef __ASSEMBLER__
#include <sys/cdefs.h>

/* Machine type dependent parameters. */
#include <machine/types.h>
#include <sys/_types.h>

#include <machine/endian.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <sys/_types/_u_char.h>
#include <sys/_types/_u_short.h>
#include <sys/_types/_u_int.h>
#ifndef _U_LONG
typedef unsigned long           u_long;
#define _U_LONG
#endif
typedef unsigned short          ushort;         /* Sys V compatibility */
typedef unsigned int            uint;           /* Sys V compatibility */
#endif

typedef u_int64_t               u_quad_t;       /* quads */
typedef int64_t                 quad_t;
typedef quad_t *                qaddr_t;

#include <sys/_types/_caddr_t.h>        /* core address */

typedef int32_t                 daddr_t;        /* disk address */

#include <sys/_types/_dev_t.h>                  /* device number */

typedef u_int32_t               fixpt_t;        /* fixed point number */

#include <sys/_types/_blkcnt_t.h>
#include <sys/_types/_blksize_t.h>
#include <sys/_types/_gid_t.h>
#include <sys/_types/_in_addr_t.h>
#include <sys/_types/_in_port_t.h>
#include <sys/_types/_ino_t.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <sys/_types/_ino64_t.h>                        /* 64bit inode number */
#endif /* !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE) */

#include <sys/_types/_key_t.h>
#include <sys/_types/_mode_t.h>
#include <sys/_types/_nlink_t.h>
#include <sys/_types/_id_t.h>
#include <sys/_types/_pid_t.h>
#include <sys/_types/_off_t.h>

typedef int32_t                 segsz_t;        /* segment size */
typedef int32_t                 swblk_t;        /* swap offset */

#include <sys/_types/_uid_t.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/* Major, minor numbers, dev_t's. */
#if defined(__cplusplus)
/*
 * These lowercase macros tend to match member functions in some C++ code,
 * so for C++, we must use inline functions instead.
 */

static inline __int32_t
major(__uint32_t _x)
{
	return (__int32_t)(((__uint32_t)_x >> 24) & 0xff);
}

static inline __int32_t
minor(__uint32_t _x)
{
	return (__int32_t)((_x) & 0xffffff);
}

static inline dev_t
makedev(__uint32_t _major, __uint32_t _minor)
{
	return (dev_t)(((_major) << 24) | (_minor));
}

#else   /* !__cplusplus */

#define major(x)        ((int32_t)(((u_int32_t)(x) >> 24) & 0xff))
#define minor(x)        ((int32_t)((x) & 0xffffff))
#define makedev(x, y)    ((dev_t)(((x) << 24) | (y)))

#endif  /* !__cplusplus */
#endif  /* !_POSIX_C_SOURCE */

#include <sys/_types/_clock_t.h>
#include <sys/_types/_size_t.h>
#include <sys/_types/_ssize_t.h>
#include <sys/_types/_time_t.h>

#include <sys/_types/_useconds_t.h>
#include <sys/_types/_suseconds_t.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <sys/_types/_rsize_t.h>
#include <sys/_types/_errno_t.h>
#endif

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/*
 * This code is present here in order to maintain historical backward
 * compatability, and is intended to be removed at some point in the
 * future; please include <sys/select.h> instead.
 */
#include <sys/_types/_fd_def.h>

#define NBBY            __DARWIN_NBBY           /* bits in a byte */
#define NFDBITS         __DARWIN_NFDBITS        /* bits per mask */
#define howmany(x, y)   __DARWIN_howmany(x, y)  /* # y's == x bits? */
typedef __int32_t       fd_mask;

/*
 * Select uses bit masks of file descriptors in longs.  These macros
 * manipulate such bit fields (the filesystem macros use chars).  The
 * extra protection here is to permit application redefinition above
 * the default size.
 */
#include <sys/_types/_fd_setsize.h>
#include <sys/_types/_fd_set.h>
#include <sys/_types/_fd_clr.h>
#include <sys/_types/_fd_zero.h>
#include <sys/_types/_fd_isset.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <sys/_types/_fd_copy.h>
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */



#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#endif /* __ASSEMBLER__ */


#ifndef __POSIX_LIB__

#include <sys/_pthread/_pthread_attr_t.h>
#include <sys/_pthread/_pthread_cond_t.h>
#include <sys/_pthread/_pthread_condattr_t.h>
#include <sys/_pthread/_pthread_mutex_t.h>
#include <sys/_pthread/_pthread_mutexattr_t.h>
#include <sys/_pthread/_pthread_once_t.h>
#include <sys/_pthread/_pthread_rwlock_t.h>
#include <sys/_pthread/_pthread_rwlockattr_t.h>
#include <sys/_pthread/_pthread_t.h>

#endif /* __POSIX_LIB__ */

#include <sys/_pthread/_pthread_key_t.h>


/* statvfs and fstatvfs */

#include <sys/_types/_fsblkcnt_t.h>
#include <sys/_types/_fsfilcnt_t.h>

#endif /* !_SYS_TYPES_H_ */