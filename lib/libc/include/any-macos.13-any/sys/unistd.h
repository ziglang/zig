/*
 * Copyright (c) 2000-2013 Apple Inc. All rights reserved.
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
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)unistd.h	8.2 (Berkeley) 1/7/94
 */

#ifndef _SYS_UNISTD_H_
#define _SYS_UNISTD_H_

#include <sys/cdefs.h>

/*
 * Although we have saved user/group IDs, we do not use them in setuid
 * as described in POSIX 1003.1, because the feature does not work for
 * root.  We use the saved IDs in seteuid/setegid, which are not currently
 * part of the POSIX 1003.1 specification.
 */
#ifdef  _NOT_AVAILABLE
#define _POSIX_SAVED_IDS        /* saved set-user-ID and set-group-ID */
#endif

#define _POSIX_VERSION          200112L
#define _POSIX2_VERSION         200112L

/* execution-time symbolic constants */
/* may disable terminal special characters */
#include <sys/_types/_posix_vdisable.h>

#define _POSIX_THREAD_KEYS_MAX 128

/* access function */
#define F_OK            0       /* test for existence of file */
#define X_OK            (1<<0)  /* test for execute or search permission */
#define W_OK            (1<<1)  /* test for write permission */
#define R_OK            (1<<2)  /* test for read permission */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/*
 * Extended access functions.
 * Note that we depend on these matching the definitions in sys/kauth.h,
 * but with the bits shifted left by 8.
 */
#define _READ_OK        (1<<9)  /* read file data / read directory */
#define _WRITE_OK       (1<<10) /* write file data / add file to directory */
#define _EXECUTE_OK     (1<<11) /* execute file / search in directory*/
#define _DELETE_OK      (1<<12) /* delete file / delete directory */
#define _APPEND_OK      (1<<13) /* append to file / add subdirectory to directory */
#define _RMFILE_OK      (1<<14) /* - / remove file from directory */
#define _RATTR_OK       (1<<15) /* read basic attributes */
#define _WATTR_OK       (1<<16) /* write basic attributes */
#define _REXT_OK        (1<<17) /* read extended attributes */
#define _WEXT_OK        (1<<18) /* write extended attributes */
#define _RPERM_OK       (1<<19) /* read permissions */
#define _WPERM_OK       (1<<20) /* write permissions */
#define _CHOWN_OK       (1<<21) /* change ownership */

#define _ACCESS_EXTENDED_MASK (_READ_OK | _WRITE_OK | _EXECUTE_OK | \
	                        _DELETE_OK | _APPEND_OK | \
	                        _RMFILE_OK | _REXT_OK | \
	                        _WEXT_OK | _RATTR_OK | _WATTR_OK | _RPERM_OK | \
	                        _WPERM_OK | _CHOWN_OK)
#endif

/* whence values for lseek(2) */
#include <sys/_types/_seek_set.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/* whence values for lseek(2); renamed by POSIX 1003.1 */
#define L_SET           SEEK_SET
#define L_INCR          SEEK_CUR
#define L_XTND          SEEK_END
#endif

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
struct accessx_descriptor {
	unsigned int ad_name_offset;
	int ad_flags;
	int ad_pad[2];
};
#define ACCESSX_MAX_DESCRIPTORS 100
#define ACCESSX_MAX_TABLESIZE   (16 * 1024)
#endif

/* configurable pathname variables */
#define _PC_LINK_MAX             1
#define _PC_MAX_CANON            2
#define _PC_MAX_INPUT            3
#define _PC_NAME_MAX             4
#define _PC_PATH_MAX             5
#define _PC_PIPE_BUF             6
#define _PC_CHOWN_RESTRICTED     7
#define _PC_NO_TRUNC             8
#define _PC_VDISABLE             9

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define _PC_NAME_CHARS_MAX       10
#define _PC_CASE_SENSITIVE               11
#define _PC_CASE_PRESERVING              12
#define _PC_EXTENDED_SECURITY_NP        13
#define _PC_AUTH_OPAQUE_NP      14
#endif

#define _PC_2_SYMLINKS          15      /* Symlink supported in directory */
#define _PC_ALLOC_SIZE_MIN      16      /* Minimum storage actually allocated */
#define _PC_ASYNC_IO            17      /* Async I/O [AIO] supported? */
#define _PC_FILESIZEBITS        18      /* # of bits to represent file size */
#define _PC_PRIO_IO             19      /* Priority I/O [PIO] supported? */
#define _PC_REC_INCR_XFER_SIZE  20      /* Recommended increment for next two */
#define _PC_REC_MAX_XFER_SIZE   21      /* Recommended max file transfer size */
#define _PC_REC_MIN_XFER_SIZE   22      /* Recommended min file transfer size */
#define _PC_REC_XFER_ALIGN      23      /* Recommended buffer alignment */
#define _PC_SYMLINK_MAX         24      /* Max # of bytes in symlink name */
#define _PC_SYNC_IO             25      /* Sync I/O [SIO] supported? */
#define _PC_XATTR_SIZE_BITS     26      /* # of bits to represent maximum xattr size */
#define _PC_MIN_HOLE_SIZE       27      /* Recommended minimum hole size for sparse files */

/* configurable system strings */
#define _CS_PATH                 1

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL

#include <machine/_types.h>
#include <sys/_types/_size_t.h>
#include <sys/_types/_ssize_t.h>
#include <_types/_uint64_t.h>
#include <_types/_uint32_t.h>
#include <Availability.h>

__BEGIN_DECLS

int     getattrlistbulk(int, void *, void *, size_t, uint64_t) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
int     getattrlistat(int, const char *, void *, void *, size_t, unsigned long) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
int     setattrlistat(int, const char *, void *, void *, size_t, uint32_t) __OSX_AVAILABLE(10.13) __IOS_AVAILABLE(11.0) __TVOS_AVAILABLE(11.0) __WATCHOS_AVAILABLE(4.0);
ssize_t freadlink(int, char * __restrict, size_t) __API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0), watchos(9.0));

__END_DECLS

#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

#if __DARWIN_C_LEVEL >= 200809L

#include <machine/_types.h>
#include <sys/_types/_size_t.h>
#include <sys/_types/_ssize_t.h>
#include <sys/_types.h>
#include <sys/_types/_uid_t.h>
#include <sys/_types/_gid_t.h>
#include <Availability.h>

__BEGIN_DECLS

int     faccessat(int, const char *, int, int) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
int     fchownat(int, const char *, uid_t, gid_t, int)  __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
int     linkat(int, const char *, int, const char *, int)       __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
ssize_t readlinkat(int, const char *, char *, size_t)   __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
int     symlinkat(const char *, int, const char *) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
int     unlinkat(int, const char *, int) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);

__END_DECLS

#endif /* __DARWIN_C_LEVEL >= 200809L */

#endif /* !_SYS_UNISTD_H_ */