/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1991, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
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
 *	@(#)types.h	8.6 (Berkeley) 2/19/95
 */

#ifndef _SYS_TYPES_H_
#define	_SYS_TYPES_H_

#include <sys/cdefs.h>

/* Machine type dependent parameters. */
#include <machine/endian.h>
#include <sys/_types.h>

#include <sys/_pthreadtypes.h>

#if __BSD_VISIBLE
typedef	unsigned char	u_char;
typedef	unsigned short	u_short;
typedef	unsigned int	u_int;
typedef	unsigned long	u_long;
#ifndef _KERNEL
typedef	unsigned short	ushort;		/* Sys V compatibility */
typedef	unsigned int	uint;		/* Sys V compatibility */
#endif
#endif

/*
 * XXX POSIX sized integrals that should appear only in <sys/stdint.h>.
 */
#include <sys/_stdint.h>

typedef __uint8_t	u_int8_t;	/* unsigned integrals (deprecated) */
typedef __uint16_t	u_int16_t;
typedef __uint32_t	u_int32_t;
typedef __uint64_t	u_int64_t;

typedef	__uint64_t	u_quad_t;	/* quads (deprecated) */
typedef	__int64_t	quad_t;
typedef	quad_t *	qaddr_t;

typedef	char *		caddr_t;	/* core address */
typedef	const char *	c_caddr_t;	/* core address, pointer to const */

#ifndef _BLKSIZE_T_DECLARED
typedef	__blksize_t	blksize_t;
#define	_BLKSIZE_T_DECLARED
#endif

typedef	__cpuwhich_t	cpuwhich_t;
typedef	__cpulevel_t	cpulevel_t;
typedef	__cpusetid_t	cpusetid_t;

#ifndef _BLKCNT_T_DECLARED
typedef	__blkcnt_t	blkcnt_t;
#define	_BLKCNT_T_DECLARED
#endif

#ifndef _CLOCK_T_DECLARED
typedef	__clock_t	clock_t;
#define	_CLOCK_T_DECLARED
#endif

#ifndef _CLOCKID_T_DECLARED
typedef	__clockid_t	clockid_t;
#define	_CLOCKID_T_DECLARED
#endif

typedef	__critical_t	critical_t;	/* Critical section value */
typedef	__daddr_t	daddr_t;	/* disk address */

#ifndef _DEV_T_DECLARED
typedef	__dev_t		dev_t;		/* device number or struct cdev */
#define	_DEV_T_DECLARED
#endif

#ifndef _FFLAGS_T_DECLARED
typedef	__fflags_t	fflags_t;	/* file flags */
#define	_FFLAGS_T_DECLARED
#endif

typedef	__fixpt_t	fixpt_t;	/* fixed point number */

#ifndef _FSBLKCNT_T_DECLARED		/* for statvfs() */
typedef	__fsblkcnt_t	fsblkcnt_t;
typedef	__fsfilcnt_t	fsfilcnt_t;
#define	_FSBLKCNT_T_DECLARED
#endif

#ifndef _GID_T_DECLARED
typedef	__gid_t		gid_t;		/* group id */
#define	_GID_T_DECLARED
#endif

#ifndef _IN_ADDR_T_DECLARED
typedef	__uint32_t	in_addr_t;	/* base type for internet address */
#define	_IN_ADDR_T_DECLARED
#endif

#ifndef _IN_PORT_T_DECLARED
typedef	__uint16_t	in_port_t;
#define	_IN_PORT_T_DECLARED
#endif

#ifndef _ID_T_DECLARED
typedef	__id_t		id_t;		/* can hold a uid_t or pid_t */
#define	_ID_T_DECLARED
#endif

#ifndef _INO_T_DECLARED
typedef	__ino_t		ino_t;		/* inode number */
#define	_INO_T_DECLARED
#endif

#ifndef _KEY_T_DECLARED
typedef	__key_t		key_t;		/* IPC key (for Sys V IPC) */
#define	_KEY_T_DECLARED
#endif

#ifndef _LWPID_T_DECLARED
typedef	__lwpid_t	lwpid_t;	/* Thread ID (a.k.a. LWP) */
#define	_LWPID_T_DECLARED
#endif

#ifndef _MODE_T_DECLARED
typedef	__mode_t	mode_t;		/* permissions */
#define	_MODE_T_DECLARED
#endif

#ifndef _ACCMODE_T_DECLARED
typedef	__accmode_t	accmode_t;	/* access permissions */
#define	_ACCMODE_T_DECLARED
#endif

#ifndef _NLINK_T_DECLARED
typedef	__nlink_t	nlink_t;	/* link count */
#define	_NLINK_T_DECLARED
#endif

#ifndef _OFF_T_DECLARED
typedef	__off_t		off_t;		/* file offset */
#define	_OFF_T_DECLARED
#endif

#ifndef _OFF64_T_DECLARED
typedef	__off64_t	off64_t;	/* file offset (alias) */
#define	_OFF64_T_DECLARED
#endif

#ifndef _PID_T_DECLARED
typedef	__pid_t		pid_t;		/* process id */
#define	_PID_T_DECLARED
#endif

typedef	__register_t	register_t;

#ifndef _RLIM_T_DECLARED
typedef	__rlim_t	rlim_t;		/* resource limit */
#define	_RLIM_T_DECLARED
#endif

typedef	__sbintime_t	sbintime_t;

typedef	__segsz_t	segsz_t;	/* segment size (in pages) */

#ifndef _SIZE_T_DECLARED
typedef	__size_t	size_t;
#define	_SIZE_T_DECLARED
#endif

#ifndef _SSIZE_T_DECLARED
typedef	__ssize_t	ssize_t;
#define	_SSIZE_T_DECLARED
#endif

#ifndef _SUSECONDS_T_DECLARED
typedef	__suseconds_t	suseconds_t;	/* microseconds (signed) */
#define	_SUSECONDS_T_DECLARED
#endif

#ifndef _TIME_T_DECLARED
typedef	__time_t	time_t;
#define	_TIME_T_DECLARED
#endif

#ifndef _TIMER_T_DECLARED
typedef	__timer_t	timer_t;
#define	_TIMER_T_DECLARED
#endif

#ifndef _MQD_T_DECLARED
typedef	__mqd_t	mqd_t;
#define	_MQD_T_DECLARED
#endif

typedef	__u_register_t	u_register_t;

#ifndef _UID_T_DECLARED
typedef	__uid_t		uid_t;		/* user id */
#define	_UID_T_DECLARED
#endif

#ifndef _USECONDS_T_DECLARED
typedef	__useconds_t	useconds_t;	/* microseconds (unsigned) */
#define	_USECONDS_T_DECLARED
#endif

#ifndef _CAP_IOCTL_T_DECLARED
#define	_CAP_IOCTL_T_DECLARED
typedef	unsigned long	cap_ioctl_t;
#endif

#ifndef _CAP_RIGHTS_T_DECLARED
#define	_CAP_RIGHTS_T_DECLARED
struct cap_rights;

typedef	struct cap_rights	cap_rights_t;
#endif

/*
 * Types suitable for exporting physical addresses, virtual addresses
 * (pointers), and memory object sizes from the kernel independent of native
 * word size.  These should be used in place of vm_paddr_t, (u)intptr_t, and
 * size_t in structs which contain such types that are shared with userspace.
 */
typedef	__uint64_t	kpaddr_t;
typedef	__uint64_t	kvaddr_t;
typedef	__uint64_t	ksize_t;
typedef	__int64_t	kssize_t;

typedef	__vm_offset_t	vm_offset_t;
typedef	__uint64_t	vm_ooffset_t;
typedef	__vm_paddr_t	vm_paddr_t;
typedef	__uint64_t	vm_pindex_t;
typedef	__vm_size_t	vm_size_t;

typedef __rman_res_t    rman_res_t;

typedef __register_t	syscallarg_t;

#ifdef _KERNEL
typedef	unsigned int	boolean_t;
typedef	struct _device	*device_t;
typedef	__intfptr_t	intfptr_t;

/*
 * XXX this is fixed width for historical reasons.  It should have had type
 * __int_fast32_t.  Fixed-width types should not be used unless binary
 * compatibility is essential.  Least-width types should be used even less
 * since they provide smaller benefits.
 *
 * XXX should be MD.
 *
 * XXX this is bogus in -current, but still used for spl*().
 */
typedef	__uint32_t	intrmask_t;	/* Interrupt mask (spl, xxx_imask...) */

typedef	__uintfptr_t	uintfptr_t;
typedef	__uint64_t	uoff_t;
typedef	char		vm_memattr_t;	/* memory attribute codes */
typedef	struct vm_page	*vm_page_t;

#define offsetof(type, field) __offsetof(type, field)
#endif /* _KERNEL */

#if	defined(_KERNEL) || defined(_STANDALONE)
#if !defined(__bool_true_false_are_defined) && !defined(__cplusplus)
#define	__bool_true_false_are_defined	1
#define	false	0
#define	true	1
typedef	_Bool	bool;
#endif /* !__bool_true_false_are_defined && !__cplusplus */
#endif /* KERNEL || _STANDALONE */

/*
 * The following are all things that really shouldn't exist in this header,
 * since its purpose is to provide typedefs, not miscellaneous doodads.
 */
#include <sys/bitcount.h>

#if __BSD_VISIBLE

#include <sys/select.h>

/*
 * The major and minor numbers are encoded in dev_t as MMMmmmMm (where
 * letters correspond to bytes).  The encoding of the lower 4 bytes is
 * constrained by compatibility with 16-bit and 32-bit dev_t's.  The
 * encoding of the upper 4 bytes is the least unnatural one consistent
 * with this and other constraints.  Also, the decoding of the m bytes by
 * minor() is unnatural to maximize compatibility subject to not discarding
 * bits.  The upper m byte is shifted into the position of the lower M byte
 * instead of shifting 3 upper m bytes to close the gap.  Compatibility for
 * minor() is achieved iff the upper m byte is 0.
 */
#define	major(d)	__major(d)
static __inline int
__major(dev_t _d)
{
	return (((_d >> 32) & 0xffffff00) | ((_d >> 8) & 0xff));
}
#define	minor(d)	__minor(d)
static __inline int
__minor(dev_t _d)
{
	return (((_d >> 24) & 0xff00) | (_d & 0xffff00ff));
}
#define	makedev(M, m)	__makedev((M), (m))
static __inline dev_t
__makedev(int _Major, int _Minor)
{
	return (((dev_t)(_Major & 0xffffff00) << 32) | ((_Major & 0xff) << 8) |
	    ((dev_t)(_Minor & 0xff00) << 24) | (_Minor & 0xffff00ff));
}

#if (defined(__clang__) || (defined(__GNUC__) && __GNUC__ >= 13))
#define __enum_uint8_decl(name)	enum enum_ ## name ## _uint8 : uint8_t
#define __enum_uint8(name)	enum enum_ ## name ## _uint8
#else
/*
 * Note: there is no real size checking here, but the code below can be
 * removed once we require GCC 13.
 */
#define __enum_uint8_decl(name)	enum __attribute__((packed)) enum_ ## name ## _uint8
#define __enum_uint8(name)	enum __attribute__((packed)) enum_ ## name ## _uint8
#endif

/*
 * These declarations belong elsewhere, but are repeated here and in
 * <stdio.h> to give broken programs a better chance of working with
 * 64-bit off_t's.
 */
#ifndef _KERNEL
__BEGIN_DECLS
#ifndef _FTRUNCATE_DECLARED
#define	_FTRUNCATE_DECLARED
int	 ftruncate(int, off_t);
#endif
#ifndef _LSEEK_DECLARED
#define	_LSEEK_DECLARED
off_t	 lseek(int, off_t, int);
#endif
#ifndef _MMAP_DECLARED
#define	_MMAP_DECLARED
void *	 mmap(void *, size_t, int, int, int, off_t);
#endif
#ifndef _TRUNCATE_DECLARED
#define	_TRUNCATE_DECLARED
int	 truncate(const char *, off_t);
#endif
__END_DECLS
#endif /* !_KERNEL */

#endif /* __BSD_VISIBLE */

#endif /* !_SYS_TYPES_H_ */