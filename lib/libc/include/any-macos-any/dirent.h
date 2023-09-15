/*
 * Copyright (c) 2000, 2002-2008 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*-
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
 *	@(#)dirent.h	8.2 (Berkeley) 7/28/94
 */

#ifndef _DIRENT_H_
#define _DIRENT_H_

/*
 * The kernel defines the format of directory entries
 */
#include <_types.h>
#include <sys/dirent.h>
#include <sys/cdefs.h>
#include <Availability.h>
#include <sys/_pthread/_pthread_types.h> /* __darwin_pthread_mutex_t */

struct _telldir;		/* forward reference */

/* structure describing an open directory. */
typedef struct {
	int	__dd_fd;	/* file descriptor associated with directory */
	long	__dd_loc;	/* offset in current buffer */
	long	__dd_size;	/* amount of data returned */
	char	*__dd_buf;	/* data buffer */
	int	__dd_len;	/* size of data buffer */
	long	__dd_seek;	/* magic cookie returned */
	__unused long	__padding; /* (__dd_rewind space left for bincompat) */
	int	__dd_flags;	/* flags for readdir */
	__darwin_pthread_mutex_t __dd_lock; /* for thread locking */
	struct _telldir *__dd_td; /* telldir position recording */
} DIR;

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL

/* definitions for library routines operating on directories. */
#define	DIRBLKSIZ	1024

/* flags for opendir2 */
#define DTF_HIDEW	0x0001	/* hide whiteout entries */
#define DTF_NODUP	0x0002	/* don't return duplicate names */
#define DTF_REWIND	0x0004	/* rewind after reading union stack */
#define __DTF_READALL	0x0008	/* everything has been read */
#define __DTF_SKIPREAD  0x0010  /* assume internal buffer is populated */
#define __DTF_ATEND     0x0020  /* there's nothing more to read in the kernel */

#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

#ifndef KERNEL

__BEGIN_DECLS

int closedir(DIR *) __DARWIN_ALIAS(closedir);

DIR *opendir(const char *) __DARWIN_ALIAS_I(opendir);

struct dirent *readdir(DIR *) __DARWIN_INODE64(readdir);
int readdir_r(DIR *, struct dirent *, struct dirent **) __DARWIN_INODE64(readdir_r);

void rewinddir(DIR *) __DARWIN_ALIAS_I(rewinddir);

void seekdir(DIR *, long) __DARWIN_ALIAS_I(seekdir);

long telldir(DIR *) __DARWIN_ALIAS_I(telldir);

__END_DECLS


/* Additional functionality provided by:
 * POSIX.1-2008
 */

#if __DARWIN_C_LEVEL >= 200809L
__BEGIN_DECLS

__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0)
DIR *fdopendir(int) __DARWIN_ALIAS_I(fdopendir);

int alphasort(const struct dirent **, const struct dirent **) __DARWIN_INODE64(alphasort);

#if (defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED < __MAC_10_8) || (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
#include <errno.h>
#include <stdlib.h>
#define dirfd(dirp) ({                         \
    DIR *_dirp = (dirp);                       \
    int ret = -1;                              \
    if (_dirp == NULL || _dirp->__dd_fd < 0)   \
        errno = EINVAL;                        \
    else                                       \
       ret = _dirp->__dd_fd;                   \
    ret;                                       \
})
#else
int dirfd(DIR *dirp) __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
#endif

int scandir(const char *, struct dirent ***,
    int (*)(const struct dirent *), int (*)(const struct dirent **, const struct dirent **)) __DARWIN_INODE64(scandir);
#ifdef __BLOCKS__
#if __has_attribute(noescape)
#define __scandir_noescape __attribute__((__noescape__))
#else
#define __scandir_noescape
#endif

int scandir_b(const char *, struct dirent ***,
    int (^)(const struct dirent *) __scandir_noescape,
    int (^)(const struct dirent **, const struct dirent **) __scandir_noescape)
    __DARWIN_INODE64(scandir_b) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#endif /* __BLOCKS__ */

__END_DECLS
#endif /* __DARWIN_C_LEVEL >= 200809L */


#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
__BEGIN_DECLS

int getdirentries(int, char *, int, long *)

#if __DARWIN_64_BIT_INO_T
/*
 * getdirentries() doesn't work when 64-bit inodes is in effect, so we
 * generate a link error.
 */
						__asm("_getdirentries_is_not_available_when_64_bit_inodes_are_in_effect")
#else /* !__DARWIN_64_BIT_INO_T */
						__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0,__MAC_10_6, __IPHONE_2_0,__IPHONE_2_0)
#endif /* __DARWIN_64_BIT_INO_T */
;

DIR *__opendir2(const char *, int) __DARWIN_ALIAS_I(__opendir2);

__END_DECLS
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

#endif /* !KERNEL */

#endif /* !_DIRENT_H_ */
