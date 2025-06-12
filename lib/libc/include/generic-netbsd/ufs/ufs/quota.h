/*	$NetBSD: quota.h,v 1.30 2012/08/26 02:32:14 dholland Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Robert Elz at The University of Melbourne.
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
 *	@(#)quota.h	8.3 (Berkeley) 8/19/94
 */

#ifndef	_UFS_UFS_QUOTA_H_
#define	_UFS_UFS_QUOTA_H_

/*
 * These definitions are common to the original disk quota implementation
 * (quota1) and the newer implementation (quota2)
 */

/*
 * The following constants define the usage of the quota file array in the
 * ufsmount structure and dquot array in the inode structure.  The semantics
 * of the elements of these arrays are defined in the routine getinoquota;
 * the remainder of the quota code treats them generically and need not be
 * inspected when changing the size of the array.
 */
#define	MAXQUOTAS	2
#define	USRQUOTA	0	/* element used for user quotas */
#define	GRPQUOTA	1	/* element used for group quotas */

/*
 * Initializer for the strings corresponding to the quota ID types.
 * (in quota1 these are also the default names of the quota files)
 */
#define INITQFNAMES { \
	"user",		/* USRQUOTA */ \
	"group",	/* GRPQUOTA */ \
}

#if !defined(HAVE_NBTOOL_CONFIG_H)
#include <sys/quota.h>
__inline static int __unused
quota_idtype_to_ufs(int idtype)
{
	switch (idtype) {
	case QUOTA_IDTYPE_USER:
		return USRQUOTA;
	case QUOTA_IDTYPE_GROUP:
		return GRPQUOTA;
	default:
		return -1;
	}
}

static __inline int __unused
quota_idtype_from_ufs(int ufstype)
{
	switch (ufstype) {
	case USRQUOTA:
		return QUOTA_IDTYPE_USER;
	case GRPQUOTA:
		return QUOTA_IDTYPE_GROUP;
	default:
		return -1;
	}
}
#endif /* !defined(HAVE_NBTOOL_CONFIG_H) */

#ifdef _KERNEL

#include <sys/cdefs.h>

__BEGIN_DECLS
void	dqinit(void);
void	dqreinit(void);
void	dqdone(void);
__END_DECLS
#endif /* _KERNEL */

#endif /* !_UFS_UFS_QUOTA_H_ */