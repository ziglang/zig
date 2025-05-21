/* $NetBSD: quota2.h,v 1.10 2017/10/25 18:06:01 jdolecek Exp $ */
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

#ifndef _UFS_UFS_QUOTA2_H_
#define _UFS_UFS_QUOTA2_H_
#include <ufs/ufs/quota.h>


/* New disk quota implementation. In this implementation, the quota datas
 * (default values, user limits and current usage) are part of the filesystem
 * metadata. On FFS, this will be in a hidden, unlinked inode. fsck_ffs is
 * responsible for checking quotas with the rest of the filesystem integrity,
 * and quotas metadata are also covered by the filesystem journal if any.
 * quota enable/disable is done on a filesystem basis via flags in the
 * superblock
 */

/*
 * The quota file is comprised of 2 parts, the header and the entries.
 * The header contains global informations, and head of list of quota entries.
 * A quota entry can either be in the free list, or one of the hash lists.
 */

/* description of a block or inode quota */
struct quota2_val {
	uint64_t q2v_hardlimit; /* absolute limit */
	uint64_t q2v_softlimit; /* overflowable limit */
	uint64_t q2v_cur; /* current usage */
	int64_t q2v_time; /* grace expiration date for softlimit overflow */
	int64_t q2v_grace; /* allowed time for softlimit overflow */
};

/*
 * On-disk description of a user or group quota
 * These entries are kept as linked list, either in one of the hash HEAD,
 * or in the free list.
 */

#define N_QL 2
#define QL_BLOCK 0
#define QL_FILE 1
#define INITQLNAMES { \
	[QL_BLOCK] = "block",	\
	[QL_FILE] =  "file",	\
}

struct quota2_entry {
	/* block & inode limits and status */
	struct quota2_val q2e_val[N_QL];
	/* pointer to next entry for this list (offset in the file) */
	uint64_t q2e_next;
	/* ownership information */
	uint32_t q2e_uid;
	uint32_t q2e_pad;
};

/* header present at the start of the quota file */
struct quota2_header {
	uint32_t q2h_magic_number;
	uint8_t  q2h_type; /* quota type, see below */
	uint8_t  q2h_hash_shift; /* bytes used for hash index */
	uint16_t q2h_hash_size; /* size of hash table */
	/* default values applied to new entries */
	struct quota2_entry q2h_defentry;
	/* head of free quota2_entry list */
	uint64_t q2h_free;
	/* variable-sized hash table */
	uint64_t q2h_entries[0];
};

#define Q2_HEAD_MAGIC	0xb746915e

/* superblock flags */
#define FS_Q2_DO_TYPE(type)	(0x01 << (type))

#define off2qindex(hsize, off) (((off) - (hsize)) / sizeof(struct quota2_entry))
#define qindex2off(hsize, idx) \
	((daddr_t)(idx) * sizeof(struct quota2_entry) + (hsize))

/* quota2_subr.c */
void quota2_addfreeq2e(struct quota2_header *, void *, uint64_t, uint64_t, int);
void quota2_create_blk0(uint64_t, void *bp, int, int, int);
void quota2_ufs_rwq2v(const struct quota2_val *, struct quota2_val *, int);
void quota2_ufs_rwq2e(const struct quota2_entry *, struct quota2_entry *, int);

/*
 * Return codes for quota_check_limit()
 */

#define QL_S_ALLOW_OK	0x00 /* below soft limit */
#define QL_S_ALLOW_SOFT	0x01 /* over soft limit */
#define QL_S_DENY_GRACE	0x02 /* over soft limit, grace time expired */
#define QL_S_DENY_HARD	0x03 /* over hard limit */
 
#define QL_F_CROSS	0x80 /* crossing soft limit */

#define QL_STATUS(x)	((x) & 0x0f)
#define QL_FLAGS(x)	((x) & 0xf0)

/* check a quota usage against limits (assumes UFS semantic) */
int quota_check_limit(uint64_t, uint64_t,  uint64_t, uint64_t, time_t, time_t);

#endif /*  _UFS_UFS_QUOTA2_H_ */