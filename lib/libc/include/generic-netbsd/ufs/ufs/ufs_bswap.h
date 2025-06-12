/*	$NetBSD: ufs_bswap.h,v 1.23 2018/04/19 21:50:10 christos Exp $	*/

/*
 * Copyright (c) 1998 Manuel Bouyer.
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
 *
 */

#ifndef _UFS_UFS_BSWAP_H_
#define _UFS_UFS_BSWAP_H_

#if defined(_KERNEL_OPT)
#include "opt_ffs.h"
#endif

#include <sys/bswap.h>

/* Macros to access UFS flags */
#ifdef FFS_EI
#define	UFS_MPNEEDSWAP(ump)	((ump)->um_flags & UFS_NEEDSWAP)
#define UFS_FSNEEDSWAP(fs)	((fs)->fs_flags & FS_SWAPPED)
#define	UFS_IPNEEDSWAP(ip)	UFS_MPNEEDSWAP((ip)->i_ump)
#else
#define	UFS_MPNEEDSWAP(ump)	((void)(ump), 0)
#define UFS_FSNEEDSWAP(fs)	((void)(fs), 0)
#define	UFS_IPNEEDSWAP(ip)	((void)(ip), 0)
#endif

#if (!defined(_KERNEL) && !defined(NO_FFS_EI)) || defined(FFS_EI)
/* inlines for access to swapped data */
static __inline u_int16_t
ufs_rw16(uint16_t a, int ns)
{
	return ((ns) ? bswap16(a) : (a));
}

static __inline u_int32_t
ufs_rw32(uint32_t a, int ns)
{
	return ((ns) ? bswap32(a) : (a));
}

static __inline u_int64_t
ufs_rw64(uint64_t a, int ns)
{
	return ((ns) ? bswap64(a) : (a));
}
#else
static __inline u_int16_t
ufs_rw16(uint16_t a, int ns)
{
	return a;
}

static __inline u_int32_t
ufs_rw32(uint32_t a, int ns)
{
	return a;
}

static __inline u_int64_t
ufs_rw64(uint64_t a, int ns)
{
	return a;
}
#endif

#define ufs_add16(a, b, ns) \
	(a) = ufs_rw16(ufs_rw16((a), (ns)) + (b), (ns))
#define ufs_add32(a, b, ns) \
	(a) = ufs_rw32(ufs_rw32((a), (ns)) + (b), (ns))
#define ufs_add64(a, b, ns) \
	(a) = ufs_rw64(ufs_rw64((a), (ns)) + (b), (ns))

#endif /* !_UFS_UFS_BSWAP_H_ */