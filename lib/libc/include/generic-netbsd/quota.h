/* $NetBSD: quota.h,v 1.7 2017/04/04 12:25:40 sevan Exp $ */

/*-
 * Copyright (c) 2011 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by David A. Holland.
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

#ifndef _QUOTA_H_
#define _QUOTA_H_

#include <sys/types.h>
#include <sys/quota.h>

struct quotahandle; /* Opaque. */
struct quotacursor; /* Opaque. */


void quotaval_clear(struct quotaval *);

struct quotahandle *quota_open(const char *);
void quota_close(struct quotahandle *);

const char *quota_getmountpoint(struct quotahandle *);
const char *quota_getmountdevice(struct quotahandle *);

const char *quota_getimplname(struct quotahandle *);
unsigned quota_getrestrictions(struct quotahandle *);

int quota_getnumidtypes(struct quotahandle *);
const char *quota_idtype_getname(struct quotahandle *, int /*idtype*/);

int quota_getnumobjtypes(struct quotahandle *);
const char *quota_objtype_getname(struct quotahandle *, int /*objtype*/);
int quota_objtype_isbytes(struct quotahandle *, int /*objtype*/);

int quota_quotaon(struct quotahandle *, int /*idtype*/);
int quota_quotaoff(struct quotahandle *, int /*idtype*/);

int quota_get(struct quotahandle *, const struct quotakey *,
	      struct quotaval *);

int quota_put(struct quotahandle *, const struct quotakey *,
	      const struct quotaval *);

int quota_delete(struct quotahandle *, const struct quotakey *);

struct quotacursor *quota_opencursor(struct quotahandle *);
void quotacursor_close(struct quotacursor *);

int quotacursor_skipidtype(struct quotacursor *, int /*idtype*/);

int quotacursor_get(struct quotacursor *, struct quotakey *,
		    struct quotaval *);

int quotacursor_getn(struct quotacursor *, struct quotakey *,
		     struct quotaval *, unsigned /*maxnum*/);

int quotacursor_atend(struct quotacursor *);
int quotacursor_rewind(struct quotacursor *);

#endif /* _QUOTA_H_ */