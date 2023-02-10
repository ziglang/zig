/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
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
/*
 * @OSF_COPYRIGHT@
 */
/*
 * Mach Operating System
 * Copyright (c) 1991,1990,1989,1988 Carnegie Mellon University
 * All Rights Reserved.
 *
 * Permission to use, copy, modify and distribute this software and its
 * documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 *
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND FOR
 * ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie Mellon
 * the rights to redistribute these changes.
 */
/*
 */
/*
 *	Mach kernel debugging interface type declarations
 */

#ifndef _MACH_DEBUG_MACH_DEBUG_TYPES_H_
#define _MACH_DEBUG_MACH_DEBUG_TYPES_H_

#include <mach_debug/ipc_info.h>
#include <mach_debug/vm_info.h>
#include <mach_debug/zone_info.h>
#include <mach_debug/page_info.h>
#include <mach_debug/hash_info.h>
#include <mach_debug/lockgroup_info.h>

#define MACH_CORE_FILEHEADER_SIGNATURE    0x0063614d20646152ULL
#define MACH_CORE_FILEHEADER_V2_SIGNATURE 0x63614d2073736f42ULL
#define MACH_CORE_FILEHEADER_MAXFILES 16
#define MACH_CORE_FILEHEADER_NAMELEN 16

/* The following are defined for mach_core_fileheader_v2 */
#define MACH_CORE_FILEHEADER_V2_FLAG_LOG_ENCRYPTED_AEA    (1ULL << 0) /* The log is encrypted using AEA */
#define MACH_CORE_FILEHEADER_V2_FLAG_EXISTING_COREFILE_KEY_FORMAT_NIST_P256 (1ULL << 8) /* The public key is an NIST-P256 ECC key */
#define MACH_CORE_FILEHEADER_V2_FLAG_NEXT_COREFILE_KEY_FORMAT_NIST_P256 (1ULL << 16) /* The next public key is an NIST-P256 ECC key */

#define MACH_CORE_FILEHEADER_V2_FLAGS_EXISTING_COREFILE_KEY_FORMAT_MASK (0x1ULL << 8) /* A bit-mask for all supported key formats */
#define MACH_CORE_FILEHEADER_V2_FLAGS_NEXT_COREFILE_KEY_FORMAT_MASK (0x1ULL << 16) /* A bit-mask for all supported next key formats */

#define MACH_CORE_FILEHEADER_V2_FLAGS_NEXT_KEY_FORMAT_TO_KEY_FORMAT(x) (((x) >> 8) & MACH_CORE_FILEHEADER_V2_FLAGS_EXISTING_COREFILE_KEY_FORMAT_MASK)

/* The following are defined for mach_core_details_v2 */
#define MACH_CORE_DETAILS_V2_FLAG_ENCRYPTED_AEA   (1ULL << 0) /* This core is encrypted using AEA */
#define MACH_CORE_DETAILS_V2_FLAG_COMPRESSED_ZLIB (1ULL << 8) /* This core is compressed using ZLib */
#define MACH_CORE_DETAILS_V2_FLAG_COMPRESSED_LZ4 (1ULL << 9) /* This core is compressed using LZ4 */

typedef char    symtab_name_t[32];

/*
 ***********************
 *
 * Mach corefile layout
 *
 ***********************
 *
 * uint64_t signature
 * uint64_t log_offset                                 >---+
 * uint64_t log_length                                     |
 * mach_core_details files[MACH_CORE_FILEHEADER_MAXFILES]  |
 *   |--> uint64_t gzip_offset                   >---+     |
 *   |    uint64_t gzip_length                       |     |
 *   |    char core_name[]                           |     |
 *   |--> uint64_t gzip_offset             >---+     |     |
 *   |    uint64_t gzip_length                 |     |     |
 *   |    char core_name[]                     |     |     |
 *   |--> [...]                                |     |     |
 * [log data. Plain-text]                      |     | <---+
 * [core #1 data. Zlib compressed]             | <---+
 * [core #2 data. Zlib compressed]         <---+
 * [core #x data...]
 */

struct mach_core_details {
	uint64_t gzip_offset;
	uint64_t gzip_length;
	char core_name[MACH_CORE_FILEHEADER_NAMELEN];
};

struct mach_core_fileheader {
	uint64_t signature; /* MACH_CORE_FILEHEADER_SIGNATURE */
	uint64_t log_offset;
	uint64_t log_length;
	uint64_t num_files;
	struct mach_core_details files[MACH_CORE_FILEHEADER_MAXFILES];
};

/*
 * Mach corefile V2 headers are denoted with MACH_CORE_FILEHEADER_V2_SIGNATURE.
 * Note that the V2 headers contain a version field that further indicates the version of the
 * header's contents. For example, if a V2 header's 'version' field indicates version 5, then
 * the header follows the format of the 'mach_core_fileheader_v5' structure.
 *
 * Further note that 'mach_core_details_' structures are not bound to the same versioning scheme
 * as the header itself. This means that it's perfectly acceptable for a 'mach_core_fileheader_v5' header
 * to make use of 'mach_core_details_v2'
 *
 **************************
 *
 * Mach corefile layout V2 (using a version 2 header struct as an example)
 *
 **************************
 *
 * uint64_t signature
 * uint32_t version
 * uint64_t flags
 * uint64_t pub_key_offset                                                             >---+
 * uint16_t pub_key_length                                                                 |
 * uint64_t log_offset                                                           >---+     |
 * uint64_t log_length                                                               |     |
 * uint64_t num_files                                                                |     |
 * mach_core_details_v2 files[]                                                      |     |
 *   |--> uint64_t flags                                                             |     |
 *   |    uint64_t offset                                                  >---+     |     |
 *   |    uint64_t length                                                      |     |     |
 *   |    char core_name[]                                                     |     |     |
 *   |--> uint64_t flags                                                       |     |     |
 *   |    uint64_t offset                                            >---+     |     |     |
 *   |    uint64_t length                                                |     |     |     |
 *   |    char core_name[]                                               |     |     |     |
 *   |--> [...]                                                          |     |     |     |
 * [public key data]                                                     |     |     | <---+
 * [log data. Plain-text or an AEA container]                            |     | <---+
 * [core #1 data. Zlib/LZ4 compressed. Possibly in an AEA container]     | <---+
 * [core #2 data. Zlib/LZ4 compressed. Possibly in an AEA container] <---+
 * [core #x data...]
 */

struct mach_core_details_v2 {
	uint64_t flags;  /* See the MACH_CORE_DETAILS_V2_FLAG_* definitions */
	uint64_t offset;
	uint64_t length;
	char core_name[MACH_CORE_FILEHEADER_NAMELEN];
};

struct mach_core_fileheader_base {
	uint64_t signature; /* MACH_CORE_FILEHEADER_V2_SIGNATURE */
	uint32_t version;
};

struct mach_core_fileheader_v2 {
	uint64_t signature;       /* MACH_CORE_FILEHEADER_V2_SIGNATURE */
	uint32_t version;         /* 2 */
	uint64_t flags;           /* See the MACH_CORE_FILEHEADER_V2_FLAG_* definitions */
	uint64_t pub_key_offset;  /* Offset of the public key */
	uint16_t pub_key_length;  /* Length of the public key */
	uint64_t log_offset;
	uint64_t log_length;
	uint64_t num_files;
	struct mach_core_details_v2 files[];
};

#define KOBJECT_DESCRIPTION_LENGTH      512
typedef char kobject_description_t[KOBJECT_DESCRIPTION_LENGTH];

#endif  /* _MACH_DEBUG_MACH_DEBUG_TYPES_H_ */