/*	$NetBSD: utoppy.h,v 1.2 2008/04/28 20:24:01 martin Exp $	*/

/*-
 * Copyright (c) 2006 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Steve C. Woodford.
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

#ifndef _DEV_USB_UTOPPY_H_
#define _DEV_USB_UTOPPY_H_

#include <sys/ioccom.h>

#define	UTOPPY_MAX_FILENAME_LEN	95
#define	UTOPPY_MAX_PATHNAME_LEN	((UTOPPY_MAX_FILENAME_LEN + 1) * 6)

/* Set/clear turbo mode */
#define	UTOPPYIOTURBO		_IOW('t', 1, int)

/* Cancel previous op */
#define	UTOPPYIOCANCEL		_IO('t', 2)

/* Reboot the toppy */
#define	UTOPPYIOREBOOT		_IO('t', 3)

/* Get status of Toppy's hard disk drive */
#define	UTOPPYIOSTATS		_IOR('t', 4, struct utoppy_stats)
struct utoppy_stats {
	uint64_t us_hdd_size;
	uint64_t us_hdd_free;
};

/* Rename a file/directory */
#define	UTOPPYIORENAME		_IOW('t', 5, struct utoppy_rename)
struct utoppy_rename {
	char *ur_old_path;
	char *ur_new_path;
};

/* Create a directory */
#define	UTOPPYIOMKDIR		_IOW('t', 6, char *)

/* Delete a file/directory */
#define	UTOPPYIODELETE		_IOW('t', 7, char *)

/* Initiate reading of the contents of a directory */
#define	UTOPPYIOREADDIR		_IOW('t', 8, char *)
struct utoppy_dirent {
	char ud_path[UTOPPY_MAX_FILENAME_LEN + 1];
	enum {
		UTOPPY_DIRENT_UNKNOWN,
		UTOPPY_DIRENT_DIRECTORY,
		UTOPPY_DIRENT_FILE
	} ud_type;
	off_t ud_size;
	time_t ud_mtime;
	uint32_t ud_attributes;
};

/* Initiate reading from a specific file */
#define	UTOPPYIOREADFILE	_IOW('t', 9, struct utoppy_readfile)
struct utoppy_readfile {
	char *ur_path;
	off_t ur_offset;
};

/* Initiate writing to a new file */
#define	UTOPPYIOWRITEFILE	_IOW('t', 10, struct utoppy_writefile)
struct utoppy_writefile {
	char *uw_path;
	off_t uw_offset;
	off_t uw_size;
	time_t uw_mtime;
};

#endif /* _DEV_USB_UTOPPY_H_ */