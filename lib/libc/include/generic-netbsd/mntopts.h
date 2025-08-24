/*	$NetBSD: mntopts.h,v 1.20 2021/09/18 03:05:20 christos Exp $	*/

/*-
 * Copyright (c) 1994
 *      The Regents of the University of California.  All rights reserved.
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
 *	@(#)mntopts.h	8.7 (Berkeley) 3/29/95
 */
#ifndef _MNTOPTS_H_
#define _MNTOPTS_H_

#include <sys/cdefs.h>

struct mntopt {
	const char *m_option;	/* option name */
	int m_inverse;		/* if a negative option, eg "dev" */
	int m_flag;		/* bit to set, eg. MNT_RDONLY */
	int m_altloc;		/* 1 => set bit in altflags */
};

/* User-visible MNT_ flags. */
#define MOPT_ACLS		{ "acls",	0, MNT_ACLS, 0 }
#define MOPT_NFS4ACLS		{ "nfs4acls",	0, MNT_NFS4ACLS, 0 }
#define MOPT_POSIX1EACLS	{ "posix1eacls",0, MNT_POSIX1EACLS, 0 }
#define MOPT_ASYNC		{ "async",	0, MNT_ASYNC, 0 }
#define MOPT_NOCOREDUMP		{ "coredump",	1, MNT_NOCOREDUMP, 0 }
#define MOPT_NODEV		{ "dev",	1, MNT_NODEV, 0 }
#define MOPT_NODEVMTIME		{ "devmtime",	1, MNT_NODEVMTIME, 0 }
#define MOPT_NOEXEC		{ "exec",	1, MNT_NOEXEC, 0 }
#define MOPT_NOSUID		{ "suid",	1, MNT_NOSUID, 0 }
#define MOPT_RDONLY		{ "rdonly",	0, MNT_RDONLY, 0 }
#define MOPT_SYNC		{ "sync",	0, MNT_SYNCHRONOUS, 0 }
#define MOPT_UNION		{ "union",	0, MNT_UNION, 0 }
#define MOPT_USERQUOTA		{ "userquota",	0, 0, 0 }
#define MOPT_GROUPQUOTA		{ "groupquota",	0, 0, 0 }
#define MOPT_NOATIME		{ "atime",	1, MNT_NOATIME, 0 }
#define MOPT_RELATIME		{ "relatime",	0, MNT_RELATIME, 0 }
#define MOPT_SYMPERM		{ "symperm",	0, MNT_SYMPERM, 0 }
#define MOPT_SOFTDEP		{ "softdep",	0, MNT_SOFTDEP, 0 }
#define MOPT_LOG		{ "log",	0, MNT_LOG, 0 }
#define MOPT_IGNORE		{ "hidden",	0, MNT_IGNORE, 0 }
#define MOPT_EXTATTR		{ "extattr",	0, MNT_EXTATTR, 0 }
#define MOPT_DISCARD		{ "discard",	0, MNT_DISCARD, 0 }
#define MOPT_AUTOMOUNTED	{ "automounted",0, MNT_AUTOMOUNTED, 0 }

/* Control flags. */
#define MOPT_FORCE		{ "force",	0, MNT_FORCE, 0 }
#define MOPT_UPDATE		{ "update",	0, MNT_UPDATE, 0 }
#define MOPT_RELOAD		{ "reload",	0, MNT_RELOAD, 0 }
#define MOPT_GETARGS		{ "getargs",	0, MNT_GETARGS,	0 }

/* Support for old-style "ro", "rw" flags. */
#define MOPT_RO			{ "ro",		0, MNT_RDONLY, 0 }
#define MOPT_RW			{ "rw",		1, MNT_RDONLY, 0 }

/* This is parsed by mount(8), but is ignored by specific mount_*(8)s. */
#define MOPT_AUTO		{ "auto",	0, 0, 0 }
#define MOPT_RUMP		{ "rump",	0, 0, 0 }
#define MOPT_NULL		{ NULL,		0, 0, 0 }

#define MOPT_FSTAB_COMPAT						\
	MOPT_RO,							\
	MOPT_RW,							\
	MOPT_AUTO

/* Standard options which all mounts can understand. */
#define MOPT_STDOPTS							\
	MOPT_USERQUOTA,							\
	MOPT_GROUPQUOTA,						\
	MOPT_FSTAB_COMPAT,						\
	MOPT_NOCOREDUMP,						\
	MOPT_NODEV,							\
	MOPT_NOEXEC,							\
	MOPT_NOSUID,							\
	MOPT_RDONLY,							\
	MOPT_UNION,							\
	MOPT_IGNORE,							\
	MOPT_SYMPERM,							\
	MOPT_RUMP,							\
	MOPT_AUTOMOUNTED

__BEGIN_DECLS
typedef struct mntoptparse *mntoptparse_t;
mntoptparse_t getmntopts(const char *, const struct mntopt *, int *, int *);
const char *getmntoptstr(mntoptparse_t, const char *);
long getmntoptnum(mntoptparse_t, const char *);
void freemntopts(mntoptparse_t);

extern int getmnt_silent;
__END_DECLS

#endif /* _MNTOPTS_H_ */