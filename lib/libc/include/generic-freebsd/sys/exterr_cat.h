/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2025 The FreeBSD Foundation
 * All rights reserved.
 *
 * This software were developed by Konstantin Belousov <kib@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
 */

#ifndef _SYS_EXTERR_CAT_H_
#define	_SYS_EXTERR_CAT_H_

#define	EXTERR_CAT_MMAP		1
#define	EXTERR_CAT_FILEDESC	2
#define	EXTERR_KTRACE		3	/* To allow inclusion of this
					   file into kern_ktrace.c */
#define	EXTERR_CAT_FUSE		4
#define	EXTERR_CAT_INOTIFY	5
#define	EXTERR_CAT_GENIO	6
#define	EXTERR_CAT_BRIDGE	7
#define	EXTERR_CAT_SWAP		8
#define	EXTERR_CAT_VFSSYSCALL	9

#endif