/*	$NetBSD: libhfs.h,v 1.8.30.1 2023/07/31 15:47:20 martin Exp $	*/

/*-
 * Copyright (c) 2005, 2007 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Yevgeny Binder, Dieter Baron, and Pelle Johansson.
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

#ifndef _FS_HFS_LIBHFS_H_
#define _FS_HFS_LIBHFS_H_

#include <sys/endian.h>
#include <sys/param.h>
#include <sys/mount.h>	/* needs to go after sys/param.h or compile fails */
#include <sys/types.h>
#if defined(_KERNEL)
#include <sys/kernel.h>
#include <sys/systm.h>
#include <sys/fcntl.h>
#endif /* defined(_KERNEL) */

#if !defined(_KERNEL) && !defined(STANDALONE)
#include <fcntl.h>
#include <iconv.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#endif /* !defined(_KERNEL) && !defined(STANDALONE) */

#define max(A,B) ((A) > (B) ? (A):(B))
#define min(A,B) ((A) < (B) ? (A):(B))


/* Macros to handle errors in this library. Not recommended outside libhfs.c */
#define HFS_LIBERR(format, ...) \
	do{ hfslib_error(format, __FILE__, __LINE__, ##__VA_ARGS__); \
		goto error; } while(/*CONSTCOND*/ 0)

#if 0
#pragma mark Constants (on-disk)
#endif


enum {
	HFS_SIG_HFSP	= 0x482B,	/* 'H+' */
	HFS_SIG_HFSX	= 0x4858,	/* 'HX' */
	HFS_SIG_HFS	= 0x4244	/* 'BD' */
}; /* volume signatures */

typedef enum {
							/* bits 0-6 are reserved */
	HFS_VOL_HWLOCK			= 7,
	HFS_VOL_UNMOUNTED		= 8,
	HFS_VOL_BADBLOCKS		= 9,
	HFS_VOL_NOCACHE		= 10,
	HFS_VOL_DIRTY			= 11,
	HFS_VOL_CNIDS_RECYCLED	= 12,
	HFS_VOL_JOURNALED		= 13,
							/* bit 14 is reserved */
	HFS_VOL_SWLOCK			= 15
							/* bits 16-31 are reserved */
} hfs_volume_attribute_bit; /* volume header attribute bits */

typedef enum {
	HFS_LEAFNODE	= -1,
	HFS_INDEXNODE	= 0,
	HFS_HEADERNODE	= 1,
	HFS_MAPNODE	= 2
} hfs_node_kind; /* btree node kinds */

enum {
	HFS_BAD_CLOSE_MASK			= 0x00000001,
	HFS_BIG_KEYS_MASK			= 0x00000002,
	HFS_VAR_INDEX_KEYS_MASK	= 0x00000004
}; /* btree header attribute masks */

typedef enum {
	HFS_CNID_ROOT_PARENT	= 1,
	HFS_CNID_ROOT_FOLDER	= 2,
	HFS_CNID_EXTENTS		= 3,
	HFS_CNID_CATALOG		= 4,
	HFS_CNID_BADBLOCKS		= 5,
	HFS_CNID_ALLOCATION	= 6,
	HFS_CNID_STARTUP		= 7,
	HFS_CNID_ATTRIBUTES	= 8,
								/* CNIDs 9-13 are reserved */
	HFS_CNID_REPAIR		= 14,
	HFS_CNID_TEMP			= 15,
	HFS_CNID_USER			= 16
} hfs_special_cnid; /* special CNID values */

typedef enum {
	HFS_REC_FLDR			= 0x0001,
	HFS_REC_FILE			= 0x0002,
	HFS_REC_FLDR_THREAD	= 0x0003,
	HFS_REC_FILE_THREAD	= 0x0004
} hfs_catalog_rec_kind; /* catalog record types */

enum {
	HFS_JOURNAL_ON_DISK_MASK		= 0x00000001, /* journal on same volume */
	HFS_JOURNAL_ON_OTHER_MASK		= 0x00000002, /* journal elsewhere */
	HFS_JOURNAL_NEEDS_INIT_MASK	= 0x00000004
}; /* journal flag masks */

enum {
	HFS_JOURNAL_HEADER_MAGIC	= 0x4a4e4c78,
	HFS_JOURNAL_ENDIAN_MAGIC	= 0x12345678
}; /* journal magic numbers */

enum {
	HFS_DATAFORK	= 0x00,
	HFS_RSRCFORK	= 0xFF
}; /* common fork types */

enum {
	HFS_KEY_CASEFOLD	= 0xCF,
	HFS_KEY_BINARY		= 0XBC
}; /* catalog key comparison method types */

enum {
	HFS_MIN_CAT_KEY_LEN	= 6,
	HFS_MAX_CAT_KEY_LEN	= 516,
	HFS_MAX_EXT_KEY_LEN	= 10
};

enum {
	HFS_HARD_LINK_FILE_TYPE = 0x686C6E6B,  /* 'hlnk' */
	HFS_HFSLUS_CREATOR     = 0x6866732B   /* 'hfs+' */
};


#if 0
#pragma mark -
#pragma mark Constants (custom)
#endif


/* number of bytes between start of volume and volume header */
#define HFS_VOLUME_HEAD_RESERVE_SIZE	1024

typedef enum {
	HFS_CATALOG_FILE = 1,
	HFS_EXTENTS_FILE = 2,
	HFS_ATTRIBUTES_FILE = 3
} hfs_btree_file_type; /* btree file kinds */


#if 0
#pragma mark -
#pragma mark On-Disk Types (Mac OS specific)
#endif

typedef uint32_t	hfs_macos_type_code; /* four 1-byte char field */

typedef struct {
	int16_t	v;
	int16_t	h;
} hfs_macos_point_t;

typedef struct {
	int16_t	t;	/* top */
	int16_t	l;	/* left */
	int16_t	b;	/* bottom */
	int16_t	r;	/* right */
} hfs_macos_rect_t;

typedef struct {
	hfs_macos_type_code	file_type;
	hfs_macos_type_code	file_creator;
	uint16_t				finder_flags;
	hfs_macos_point_t	location;
	uint16_t				reserved;
} hfs_macos_file_info_t;

typedef struct {
	int16_t	reserved[4];
	uint16_t	extended_finder_flags;
	int16_t	reserved2;
	int32_t	put_away_folder_cnid;
} hfs_macos_extended_file_info_t;

typedef struct {
	hfs_macos_rect_t		window_bounds;
	uint16_t				finder_flags;
	hfs_macos_point_t	location;
	uint16_t				reserved;
} hfs_macos_folder_info_t;

typedef struct {
	hfs_macos_point_t	scroll_position;
	int32_t				reserved;
	uint16_t				extended_finder_flags;
	int16_t				reserved2;
	int32_t				put_away_folder_cnid;
} hfs_macos_extended_folder_info_t;


#if 0
#pragma mark -
#pragma mark On-Disk Types
#endif

typedef uint16_t unichar_t;

typedef uint32_t hfs_cnid_t;

typedef struct {
	uint16_t	length;
	unichar_t	unicode[255];
} hfs_unistr255_t;

typedef struct {
	uint32_t	start_block;
	uint32_t	block_count;
} hfs_extent_descriptor_t;

typedef hfs_extent_descriptor_t hfs_extent_record_t[8];

typedef struct hfs_fork_t {
	uint64_t				logical_size;
	uint32_t				clump_size;
	uint32_t				total_blocks;
	hfs_extent_record_t	extents;
} hfs_fork_t;

typedef struct {
	uint16_t	signature;
	uint16_t	version;
	uint32_t	attributes;
	uint32_t	last_mounting_version;
	uint32_t	journal_info_block;

	uint32_t	date_created;
	uint32_t	date_modified;
	uint32_t	date_backedup;
	uint32_t	date_checked;

	uint32_t	file_count;
	uint32_t	folder_count;

	uint32_t	block_size;
	uint32_t	total_blocks;
	uint32_t	free_blocks;

	uint32_t	next_alloc_block;
	uint32_t	rsrc_clump_size;
	uint32_t	data_clump_size;
	hfs_cnid_t	next_cnid;

	uint32_t	write_count;
	uint64_t	encodings;

	uint32_t	finder_info[8];

	hfs_fork_t	allocation_file;
	hfs_fork_t	extents_file;
	hfs_fork_t	catalog_file;
	hfs_fork_t	attributes_file;
	hfs_fork_t	startup_file;
} hfs_volume_header_t;

typedef struct {
	uint32_t	flink;
	uint32_t	blink;
	int8_t		kind;
	uint8_t		height;
	uint16_t	num_recs;
	uint16_t	reserved;
} hfs_node_descriptor_t;

typedef struct {
	uint16_t	tree_depth;
	uint32_t	root_node;
	uint32_t	leaf_recs;
	uint32_t	first_leaf;
	uint32_t	last_leaf;
	uint16_t	node_size;
	uint16_t	max_key_len;
	uint32_t	total_nodes;
	uint32_t	free_nodes;
	uint16_t	reserved;
	uint32_t	clump_size;		/* misaligned */
	uint8_t		btree_type;
	uint8_t		keycomp_type;
	uint32_t	attributes;		/* long aligned again */
	uint32_t	reserved2[16];
} hfs_header_record_t;

typedef struct {
	uint16_t			key_len;
	hfs_cnid_t			parent_cnid;
	hfs_unistr255_t	name;
} hfs_catalog_key_t;

typedef struct {
	uint16_t	key_length;
	uint8_t		fork_type;
	uint8_t		padding;
	hfs_cnid_t	file_cnid;
	uint32_t	start_block;
} hfs_extent_key_t;

typedef struct {
	uint32_t	owner_id;
	uint32_t	group_id;
	uint8_t		admin_flags;
	uint8_t		owner_flags;
	uint16_t	file_mode;
	union {
		uint32_t	inode_num;
		uint32_t	link_count;
		uint32_t	raw_device;
	} special;
} hfs_bsd_data_t;

typedef struct {
	int16_t			rec_type;
	uint16_t		flags;
	uint32_t		valence;
	hfs_cnid_t		cnid;
	uint32_t		date_created;
	uint32_t		date_content_mod;
	uint32_t		date_attrib_mod;
	uint32_t		date_accessed;
	uint32_t		date_backedup;
	hfs_bsd_data_t						bsd;
	hfs_macos_folder_info_t			user_info;
	hfs_macos_extended_folder_info_t	finder_info;
	uint32_t		text_encoding;
	uint32_t		reserved;
} hfs_folder_record_t;

typedef struct {
	int16_t			rec_type;
	uint16_t		flags;
	uint32_t		reserved;
	hfs_cnid_t		cnid;
	uint32_t		date_created;
	uint32_t		date_content_mod;
	uint32_t		date_attrib_mod;
	uint32_t		date_accessed;
	uint32_t		date_backedup;
	hfs_bsd_data_t						bsd;
	hfs_macos_file_info_t				user_info;
	hfs_macos_extended_file_info_t		finder_info;
	uint32_t		text_encoding;
	uint32_t		reserved2;
	hfs_fork_t		data_fork;
	hfs_fork_t		rsrc_fork;
} hfs_file_record_t;

typedef struct {
	int16_t				rec_type;
	int16_t				reserved;
	hfs_cnid_t			parent_cnid;
	hfs_unistr255_t	name;
} hfs_thread_record_t;

typedef struct {
	uint32_t	flags;
	uint32_t	device_signature[8];
	uint64_t	offset;
	uint64_t	size;
	uint64_t	reserved[32];
} hfs_journal_info_t;

typedef struct {
	uint32_t	magic;
	uint32_t	endian;
	uint64_t	start;
	uint64_t	end;
	uint64_t	size;
	uint32_t	blocklist_header_size;
	uint32_t	checksum;
	uint32_t	journal_header_size;
} hfs_journal_header_t;

/* plain HFS structures needed for hfs wrapper support */

typedef struct {
	uint16_t        start_block;
	uint16_t        block_count;
} hfs_hfs_extent_descriptor_t;

typedef hfs_hfs_extent_descriptor_t hfs_hfs_extent_record_t[3];

typedef struct {
	uint16_t        signature;
	uint32_t        date_created;
	uint32_t        date_modified;
	uint16_t        attributes;
	uint16_t        root_file_count;
	uint16_t        volume_bitmap;
	uint16_t        next_alloc_block;
	uint16_t        total_blocks;
	uint32_t        block_size;
	uint32_t        clump_size;
	uint16_t        first_block;
	hfs_cnid_t      next_cnid;
	uint16_t        free_blocks;
	unsigned char   volume_name[28];
	uint32_t        date_backedup;
	uint16_t        backup_seqnum;
	uint32_t        write_count;
	uint32_t        extents_clump_size;
	uint32_t        catalog_clump_size;
	uint16_t        root_folder_count;
	uint32_t        file_count;
	uint32_t        folder_count;
	uint32_t        finder_info[8];
	uint16_t        embedded_signature;
	hfs_hfs_extent_descriptor_t embedded_extent;
	uint32_t        extents_size;
	hfs_hfs_extent_record_t extents_extents;
	uint32_t        catalog_size;
	hfs_hfs_extent_record_t catalog_extents;
} hfs_hfs_master_directory_block_t;

#if 0
#pragma mark -
#pragma mark Custom Types
#endif

typedef struct {
	hfs_volume_header_t	vh;		/* volume header */
	hfs_header_record_t	chr;	/* catalog file header node record*/
	hfs_header_record_t	ehr;	/* extent overflow file header node record*/
	uint8_t	catkeysizefieldsize;	/* size of catalog file key_len field in
									 * bytes (1 or 2); always 2 for HFS+ */
	uint8_t	extkeysizefieldsize;	/* size of extent file key_len field in
									 * bytes (1 or 2); always 2 for HFS+ */
	hfs_unistr255_t		name;	/* volume name */

	/* pointer to catalog file key comparison function */
	int (*keycmp) (const void*, const void*);

	int						journaled;	/* 1 if volume is journaled, else 0 */
	hfs_journal_info_t		jib;	/* journal info block */
	hfs_journal_header_t	jh;		/* journal header */

	uint64_t offset;	/* offset, in bytes, of HFS+ volume */
	int		readonly;	/* 0 if mounted r/w, 1 if mounted r/o */
	void*	cbdata;		/* application-specific data; allocated, defined and
						 * used (if desired) by the program, usually within
						 * callback routines */
} hfs_volume;

typedef union {
	/* for leaf nodes */
	int16_t					type; /* type of record: folder, file, or thread */
	hfs_folder_record_t	folder;
	hfs_file_record_t		file;
	hfs_thread_record_t	thread;

	/* for pointer nodes */
	/* (using this large union for just one tiny field is not memory-efficient,
	 *	 so change this if it becomes problematic) */ 
	uint32_t	child;	/* node number of this node's child node */
} hfs_catalog_keyed_record_t;

/*
 * These arguments are passed among libhfs without any inspection. This struct
 * is accepted by all public functions of libhfs, and passed to each callback.
 * An application dereferences each pointer to its own specific struct of
 * arguments. Callbacks must be prepared to deal with NULL values for any of
 * these fields (by providing default values to be used in lieu of that
 * argument). However, a NULL pointer to this struct is an error.
 *
 * It was decided to make one unified argument structure, rather than many
 * separate, operand-specific structures, because, when this structure is passed
 * to a public function (e.g., hfslib_open_volume()), the function may make
 * several calls (and subcalls) to various facilities, e.g., read(), malloc(),
 * and free(), all of which require their own particular arguments. The
 * facilities to be used are quite impractical to foreshadow, so the application
 * takes care of all possible calls at once. This also reinforces the idea that
 * a public call is an umbrella to a set of system calls, and all of these calls
 * must be passed arguments which do not change within the context of this
 * umbrella. (E.g., if a public function makes two calls to read(), one call
 * should not be passed a uid of root and the other passed a uid of daemon.)
 */
typedef struct {
	/* The 'error' function does not take an argument. All others do. */

	void*	allocmem;
	void*	reallocmem;
	void*	freemem;
	void*	openvol;
	void*	closevol;
	void*	read;
} hfs_callback_args;

typedef struct {
	/* error(in_format, in_file, in_line, in_args) */
	void (*error) (const char*, const char*, int, va_list);

	/* allocmem(in_size, cbargs) */
	void* (*allocmem) (size_t, hfs_callback_args*);

	/* reallocmem(in_ptr, in_size, cbargs) */
	void* (*reallocmem) (void*, size_t, hfs_callback_args*);

	/* freemem(in_ptr, cbargs) */
	void (*freemem) (void*, hfs_callback_args*);

	/* openvol(in_volume, in_devicepath, cbargs)
	 * returns 0 on success */
	int (*openvol) (hfs_volume*, const char*, hfs_callback_args*);

	/* closevol(in_volume, cbargs) */
	void (*closevol) (hfs_volume*, hfs_callback_args*);

	/* read(in_volume, out_buffer, in_length, in_offset, cbargs)
	 * returns 0 on success */
	int (*read) (hfs_volume*, void*, uint64_t, uint64_t,
		hfs_callback_args*);
} hfs_callbacks;

extern hfs_callbacks	hfs_gcb;	/* global callbacks */

/*
 * global case folding table
 * (lazily initialized; see comments at bottom of hfs_open_volume())
 */
extern unichar_t* hfs_gcft;

#if 0
#pragma mark -
#pragma mark Functions
#endif

void hfslib_init(hfs_callbacks*);
void hfslib_done(void);
void hfslib_init_cbargs(hfs_callback_args*);

int hfslib_open_volume(const char*, int, hfs_volume*,
	hfs_callback_args*);
void hfslib_close_volume(hfs_volume*, hfs_callback_args*);

int hfslib_path_to_cnid(hfs_volume*, hfs_cnid_t, char**, uint16_t*,
	hfs_callback_args*);
hfs_cnid_t hfslib_find_parent_thread(hfs_volume*, hfs_cnid_t,
	hfs_thread_record_t*, hfs_callback_args*);
int hfslib_find_catalog_record_with_cnid(hfs_volume*, hfs_cnid_t,
	hfs_catalog_keyed_record_t*, hfs_catalog_key_t*, hfs_callback_args*);
int hfslib_find_catalog_record_with_key(hfs_volume*, hfs_catalog_key_t*,
	hfs_catalog_keyed_record_t*, hfs_callback_args*);
int hfslib_find_extent_record_with_key(hfs_volume*, hfs_extent_key_t*,
	hfs_extent_record_t*, hfs_callback_args*);
int hfslib_get_directory_contents(hfs_volume*, hfs_cnid_t,
	hfs_catalog_keyed_record_t**, hfs_unistr255_t**, uint32_t*,
	hfs_callback_args*);
int hfslib_is_journal_clean(hfs_volume*);
int hfslib_is_private_file(hfs_catalog_key_t*);

int hfslib_get_hardlink(hfs_volume *, uint32_t,
			 hfs_catalog_keyed_record_t *, hfs_callback_args *);

size_t hfslib_read_volume_header(void*, hfs_volume_header_t*);
size_t hfslib_read_master_directory_block(void*,
	hfs_hfs_master_directory_block_t*);
size_t hfslib_reada_node(void*, hfs_node_descriptor_t*, void***, uint16_t**,
	hfs_btree_file_type, hfs_volume*, hfs_callback_args*);
size_t hfslib_reada_node_offsets(void*, uint16_t*, uint16_t);
size_t hfslib_read_header_node(void**, uint16_t*, uint16_t,
	hfs_header_record_t*, void*, void*);
size_t hfslib_read_catalog_keyed_record(void*, hfs_catalog_keyed_record_t*,
	int16_t*, hfs_catalog_key_t*, hfs_volume*);
size_t hfslib_read_extent_record(void*, hfs_extent_record_t*, hfs_node_kind,
	hfs_extent_key_t*, hfs_volume*);
void hfslib_free_recs(void***, uint16_t**, uint16_t*, hfs_callback_args*);

size_t hfslib_read_fork_descriptor(void*, hfs_fork_t*);
size_t hfslib_read_extent_descriptors(void*, hfs_extent_record_t*);
size_t hfslib_read_unistr255(void*, hfs_unistr255_t*);
size_t hfslib_read_bsd_data(void*, hfs_bsd_data_t*);
size_t hfslib_read_file_userinfo(void*, hfs_macos_file_info_t*);
size_t hfslib_read_file_finderinfo(void*, hfs_macos_extended_file_info_t*);
size_t hfslib_read_folder_userinfo(void*, hfs_macos_folder_info_t*);
size_t hfslib_read_folder_finderinfo(void*, hfs_macos_extended_folder_info_t*);
size_t hfslib_read_journal_info(void*, hfs_journal_info_t*);
size_t hfslib_read_journal_header(void*, hfs_journal_header_t*);

uint16_t hfslib_make_catalog_key(hfs_cnid_t, uint16_t, unichar_t*,
	hfs_catalog_key_t*);
uint16_t hfslib_make_extent_key(hfs_cnid_t, uint8_t, uint32_t,
	hfs_extent_key_t*);
uint16_t hfslib_get_file_extents(hfs_volume*, hfs_cnid_t, uint8_t,
	hfs_extent_descriptor_t**, hfs_callback_args*);
int hfslib_readd_with_extents(hfs_volume*, void*, uint64_t*, uint64_t,
	uint64_t, hfs_extent_descriptor_t*, uint16_t, hfs_callback_args*);

int hfslib_compare_catalog_keys_cf(const void*, const void*);
int hfslib_compare_catalog_keys_bc(const void*, const void*);
int hfslib_compare_extent_keys(const void*, const void*);


/* callback wrappers */
void hfslib_error(const char*, const char*, int, ...) __attribute__ ((format (printf, 1, 4)));
void* hfslib_malloc(size_t, hfs_callback_args*);
void* hfslib_realloc(void*, size_t, hfs_callback_args*);
void hfslib_free(void*, hfs_callback_args*);
int hfslib_openvoldevice(hfs_volume*, const char*, hfs_callback_args*);
void hfslib_closevoldevice(hfs_volume*, hfs_callback_args*);
int hfslib_readd(hfs_volume*, void*, uint64_t, uint64_t, hfs_callback_args*);

#endif /* !_FS_HFS_LIBHFS_H_ */