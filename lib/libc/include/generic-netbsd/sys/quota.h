/* $NetBSD: quota.h,v 1.12 2012/01/30 00:56:19 dholland Exp $ */
/*-
  * Copyright (c) 2010 Manuel Bouyer
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

#ifndef _SYS_QUOTA_H_
#define _SYS_QUOTA_H_

#include <sys/types.h>

/* quota id types (entities being billed) */
#define QUOTA_IDTYPE_USER	0
#define QUOTA_IDTYPE_GROUP	1

/* quota object types (things being limited) */
#define QUOTA_OBJTYPE_BLOCKS	0
#define QUOTA_OBJTYPE_FILES	1

/* id value for "default" */
#define QUOTA_DEFAULTID		((id_t)-1)

/* limit value for "no limit" */
#define QUOTA_NOLIMIT		((uint64_t)0xffffffffffffffffULL)

/* time value for "no time" */
#define QUOTA_NOTIME		((time_t)-1)

/*
 * Semantic restrictions. These are hints applications can use
 * to help produce comprehensible error diagnostics when something
 * unsupported is attempted.
 */
#define QUOTA_RESTRICT_NEEDSQUOTACHECK	0x1	/* quotacheck(8) required */
#define QUOTA_RESTRICT_UNIFORMGRACE	0x2	/* grace time is global */
#define QUOTA_RESTRICT_32BIT		0x4	/* values limited to 2^32 */
#define QUOTA_RESTRICT_READONLY		0x8	/* updates not supported */


/*
 * Structure used to describe the key part of a quota record.
 */
struct quotakey {
	int qk_idtype;		/* type of id (user, group, etc.) */
	id_t qk_id;		/* actual id number */
	int qk_objtype;		/* type of fs object (blocks, files, etc.) */
};

/*
 * Structure used to describe the value part of a quota record.
 */
struct quotaval {
        uint64_t qv_hardlimit;	/* absolute limit */
	uint64_t qv_softlimit;	/* overflowable limit */
	uint64_t qv_usage;	/* current usage */
	time_t qv_expiretime;	/* time when softlimit grace expires */
	time_t qv_grace;	/* allowed time for overflowing soft limit */
};

#endif /* _SYS_QUOTA_H_ */