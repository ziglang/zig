/*	$NetBSD: wapbl_replay.h,v 1.1 2008/11/24 16:05:21 joerg Exp $	*/

/*-
 * Copyright (c) 2003,2008 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Wasabi Systems, Inc.
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

#ifndef _SYS_WAPBL_REPLAY_H
#define	_SYS_WAPBL_REPLAY_H

#include <sys/types.h>

/* The WAPBL journal layout.
 * 
 * The journal consists of a header followed by a circular buffer
 * region.  The circular data area is described by the header
 * wc_circ_off, wc_circ_size, wc_head and wc_tail fields as bytes
 * from the start of the journal header.  New records are inserted
 * at wc_head and the oldest valid record can be found at wc_tail.
 * When ((wc_head == wc_tail) && (wc_head == 0)), the journal is empty.
 * The condition of ((wc_head == wc_tail) && (wc_head != 0))
 * indicates a full journal, although this condition is rare.
 *
 * The journal header as well as its records are marked by a 32bit
 * type tag and length for ease of parsing.  Journal records are
 * padded so as to fall on journal device block boundaries.
 */

/*
 * The following are the 4 record types used by the journal:
 * Each tag indicates journal data organized by one of the
 * structures used below.
 */
enum {
	WAPBL_WC_HEADER = 0x5741424c,	/* "WABL", struct wapbl_wc_header */
	WAPBL_WC_INODES,		/* struct wapbl_wc_inodelist */
	WAPBL_WC_REVOCATIONS,		/* struct wapbl_wc_blocklist */
	WAPBL_WC_BLOCKS,		/* struct wapbl_wc_blocklist */
};

/* null entry (on disk) */
/* This structure isn't used directly, but shares its header
 * layout with all the other log structures for the purpose
 * of reading a log structure and determining its type
 */
struct wapbl_wc_null {
	uint32_t	wc_type;	/* WAPBL_WC_* */
	int32_t		wc_len;
	uint8_t		wc_spare[0];	/* actually longer */
};

/* journal header (on-disk)
 * This record is found at the start of the
 * journal, but not within the circular buffer region.  As well as
 * describing the journal parameters and matching filesystem, it
 * additionally serves as the atomic update record for journal
 * updates.
 */
struct wapbl_wc_header {
	uint32_t	wc_type;	/* WAPBL_WC_HEADER log magic number */
	int32_t		wc_len;		/* length of this journal entry */
	uint32_t	wc_checksum;
	uint32_t	wc_generation;
	int32_t		wc_fsid[2];
	uint64_t	wc_time;
	uint32_t	wc_timensec;
	uint32_t	wc_version;
	uint32_t	wc_log_dev_bshift;
	uint32_t	wc_fs_dev_bshift;
	int64_t		wc_head;
	int64_t		wc_tail;
	int64_t		wc_circ_off;	/* offset of of circ buffer region */
	int64_t		wc_circ_size;	/* size of circular buffer region */
	uint8_t		wc_spare[0];	/* actually longer */
};

/* list of blocks (on disk)
 * This record is used to describe a set of filesystem blocks,
 * and is used with two type tags, WAPBL_WC_BLOCKS and
 * WAPBL_WC_REVOCATIONS.
 * 
 * For WAPBL_WC_BLOCKS, a copy of each listed block can be found
 * starting at the next log device blocksize boundary.  starting at
 * one log device block since the start of the record.  This contains
 * the bulk of the filesystem journal data which is written using
 * these records before being written into the filesystem.
 *
 * The WAPBL_WC_REVOCATIONS record is used to indicate that any
 * previously listed blocks should not be written into the filesystem.
 * This is important so that deallocated and reallocated data blocks
 * do not get overwritten with stale data from the journal.  The
 * revocation records do not contain a copy of any actual block data.
 */
struct wapbl_wc_blocklist {
	uint32_t	wc_type; /* WAPBL_WC_{REVOCATIONS,BLOCKS} */
	int32_t		wc_len;
	int32_t		wc_blkcount;
	int32_t		wc_unused;
	struct {
		int64_t	wc_daddr;
		int32_t	wc_unused;
		int32_t	wc_dlen;
	} wc_blocks[0];			/* actually longer */
};

/* list of inodes (on disk)
 * This record is used to describe the set of inodes which
 * may be allocated but are unlinked.  Inodes end up listed here
 * while they are in the process of being initialized and
 * deinitialized.  Inodes unlinked while in use by a process
 * will be listed here and the actual deletion must be completed
 * on journal replay.
 */
struct wapbl_wc_inodelist {
	uint32_t	wc_type; /* WAPBL_WC_INODES */
	int32_t		wc_len;
	int32_t		wc_inocnt;
	int32_t		wc_clear;	/* set if previously listed inodes 
					   hould be ignored */
	struct {
		uint32_t wc_inumber;
		uint32_t wc_imode;
	} wc_inodes[0];		/* actually longer */
};

#endif /* _SYS_WAPBL_REPLAY_H */