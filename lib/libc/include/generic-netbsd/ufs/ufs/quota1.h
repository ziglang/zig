/*	$NetBSD: quota1.h,v 1.7 2012/08/26 02:32:14 dholland Exp $	*/

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

#ifndef	_UFS_UFS_QUOTA1_H_
#define	_UFS_UFS_QUOTA1_H_

#include <sys/quota.h>
#include <ufs/ufs/quota.h>

/*
 * These definitions are for the original disk quota implementation, which
 * is deprecated. the newer implementation is defined in quota2.h
 * and friends
 */

/*
 * Definitions for disk quotas imposed on the average user
 * (big brother finally hits UNIX).
 *
 * The following constants define the amount of time given a user before the
 * soft limits are treated as hard limits (usually resulting in an allocation
 * failure). The timer is started when the user crosses their soft limit, it
 * is reset when they go below their soft limit.
 */
#define	MAX_IQ_TIME	(7*24*60*60)	/* seconds in 1 week */
#define	MAX_DQ_TIME	(7*24*60*60)	/* seconds in 1 week */

#define	QUOTAFILENAME	"quota"
#define	QUOTAGROUP	"operator"

/*
 * Command definitions for the 'compat_50_quotactl' system call.  The commands
 * are broken into a main command defined below and a subcommand that is used
 * to convey the type of quota that is being manipulated (see above).
 */
#define SUBCMDMASK	0x00ff
#define SUBCMDSHIFT	8
#define	QCMD(cmd, type)	(((cmd) << SUBCMDSHIFT) | ((type) & SUBCMDMASK))

#define	Q_QUOTAON	0x0100	/* enable quotas */
#define	Q_QUOTAOFF	0x0200	/* disable quotas */
#define	Q_GETQUOTA	0x0300	/* get limits and usage */
#define	Q_SETQUOTA	0x0400	/* set limits and usage */
#define	Q_SETUSE	0x0500	/* set usage */
#define	Q_SYNC		0x0600	/* sync disk copy of a filesystems quotas */

/*
 * The following structure defines the format of the disk quota file
 * (as it appears on disk) - the file is an array of these structures
 * indexed by user or group number.  The setquota system call establishes
 * the vnode for each quota file (a pointer is retained in the ufsmount
 * structure).
 */
struct dqblk {
	u_int32_t dqb_bhardlimit;	/* absolute limit on disk blks alloc */
	u_int32_t dqb_bsoftlimit;	/* preferred limit on disk blks */
	u_int32_t dqb_curblocks;	/* current block count */
	u_int32_t dqb_ihardlimit;	/* maximum # allocated inodes + 1 */
	u_int32_t dqb_isoftlimit;	/* preferred inode limit */
	u_int32_t dqb_curinodes;	/* current # allocated inodes */
	int32_t	  dqb_btime;		/* time limit for excessive disk use */
	int32_t	  dqb_itime;		/* time limit for excessive files */
};

/* quota1_subr.c */
void dqblk_to_quotavals(const struct dqblk *,
			struct quotaval *, struct quotaval *);
void quotavals_to_dqblk(const struct quotaval *, const struct quotaval *,
			struct dqblk *);

#endif /* !_UFS_UFS_QUOTA1_H_ */