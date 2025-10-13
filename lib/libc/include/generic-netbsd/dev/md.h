/*	$NetBSD: md.h,v 1.11 2009/12/14 03:11:22 uebayasi Exp $	*/

/*
 * Copyright (c) 1995 Gordon W. Ross
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_DEV_MD_H_
#define _SYS_DEV_MD_H_

/*
 * Memory-disk ioctl functions:
 */

#include <sys/ioccom.h>

struct md_conf {
	void *md_addr;
	size_t  md_size;
	int     md_type;
};

#define MD_GETCONF	_IOR('r', 0, struct md_conf)	/* get unit config */
#define MD_SETCONF	_IOW('r', 1, struct md_conf)	/* set unit config */

/*
 * There are three configurations supported for each unit,
 * reflected in the value of the md_type field:
 */
#define MD_UNCONFIGURED 0
/*
 *     Not yet configured.  Open returns ENXIO.
 */
#define MD_KMEM_FIXED	1
/*
 *     Disk image resident in kernel (patched in or loaded).
 *     Requires that the function: md_set_kmem() is called to
 *     attach the (initialized) kernel memory to be used by the
 *     device.  It can be initialized by an "open hook" if this
 *     driver is compiled with the MD_OPEN_HOOK option.
 *     No attempt will ever be made to free this memory.
 */
#define MD_KMEM_ALLOCATED 2
/*
 *     Small, wired-down chunk of kernel memory obtained from
 *     kmem_alloc().  The allocation is performed by an ioctl
 *     call on the raw partition.
 */
#define MD_UMEM_SERVER 3
/*
 *     Indirect access to user-space of a user-level server.
 *     (Like the MFS hack, but better! 8^)  Device operates
 *     only while the server has the raw partition open and
 *     continues to service I/O requests.  The process that
 *     does this setconf will become the I/O server.  This
 *     configuration type can be disabled using:
 *         options  MEMORY_DISK_SERVER=0
 */

#ifdef	_KERNEL
/*
 * If the option MEMORY_DISK_HOOKS is on, then these functions are
 * called by the ramdisk driver to allow machine-dependent to
 * match/configure and/or load each ramdisk unit.
 */
extern void md_attach_hook(int, struct md_conf *);
extern void md_open_hook(int, struct md_conf *);
extern void md_root_setconf(char *, size_t);

extern int md_is_root;
#endif /* _KERNEL */

#endif /* _SYS_DEV_MD_H_ */