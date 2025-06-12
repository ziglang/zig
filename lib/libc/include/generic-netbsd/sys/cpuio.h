/*	$NetBSD: cpuio.h,v 1.10 2022/07/10 09:59:22 riastradh Exp $	*/

/*-
 * Copyright (c) 2007, 2009, 2012 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Andrew Doran.
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

#if !defined(_SYS_CPUIO_H_)
#define	_SYS_CPUIO_H_

#include <sys/types.h>
#include <sys/time.h>
#include <sys/ioccom.h>

#ifndef _KERNEL
#include <limits.h>
#include <stdbool.h>
#endif

/*
 * This is not a great place to describe CPU properties, those
 * are better returned via autoconf.
 */
typedef struct cpustate {
	u_int		cs_id;		/* matching ci_cpuid */
	uint8_t		cs_online;	/* running unbound LWPs */
	uint8_t		cs_intr;	/* fielding interrupts */
	uint8_t		cs_unused[2];	/* reserved */
	int32_t		cs_lastmod;	/* time of last state change */
	char		cs_name[16];	/* reserved */
	int32_t		cs_lastmodhi;	/* time of last state change */
	uint32_t	cs_intrcnt;	/* count of interrupt handlers + 1 */
	uint32_t	cs_hwid;	/* hardware id */
	uint32_t	cs_reserved;	/* reserved */
} cpustate_t;

#define	IOC_CPU_SETSTATE	_IOW('c', 0, cpustate_t)
#define	IOC_CPU_GETSTATE	_IOWR('c', 1, cpustate_t)
#define	IOC_CPU_GETCOUNT	_IOR('c', 2, int)
#define	IOC_CPU_MAPID		_IOWR('c', 3, int)
/* 4 and 5 reserved for compat nb6 x86 amd ucode loader */

struct cpu_ucode_version {
	int loader_version;	/* IN: md version number */
	void *data;		/* OUT: CPU ID data */
};

#define IOC_CPU_UCODE_GET_VERSION	_IOWR('c', 6, struct cpu_ucode_version)

#ifdef __i386__
/* In order to read the info from an amd64 kernel we need ... */
struct cpu_ucode_version_64 {
	int loader_version;	/* IN: md version number */
	int pad1;
	void *data;		/* OUT: CPU ID data */
	int must_be_zero;
};
#define IOC_CPU_UCODE_GET_VERSION_64	_IOWR('c', 6, struct cpu_ucode_version_64)
#endif

struct cpu_ucode {
	int loader_version;	/* md version number */
	int cpu_nr;		/* CPU index or special value below */
#define CPU_UCODE_ALL_CPUS (-1)
#define CPU_UCODE_CURRENT_CPU (-2)
	char fwname[PATH_MAX];
};

#define IOC_CPU_UCODE_APPLY		_IOW('c', 7, struct cpu_ucode)

#endif /* !_SYS_CPUIO_H_ */