/*	$NetBSD: nvmm.h,v 1.16 2021/03/26 15:59:53 reinoud Exp $	*/

/*
 * Copyright (c) 2018-2020 Maxime Villard, m00nbsd.net
 * All rights reserved.
 *
 * This code is part of the NVMM hypervisor.
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
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NVMM_H_
#define _NVMM_H_

#include <sys/types.h>

#ifndef _KERNEL
#include <stdbool.h>
#endif

typedef uint64_t	gpaddr_t;
typedef uint64_t	gvaddr_t;

typedef uint32_t	nvmm_machid_t;
typedef uint32_t	nvmm_cpuid_t;

#if defined(__x86_64__)
#include <dev/nvmm/x86/nvmm_x86.h>
#endif

#define NVMM_KERN_VERSION		2

/*
 * Version 1 - Initial release in NetBSD 9.0.
 * Version 2 - Added nvmm_vcpu::stop.
 */

struct nvmm_capability {
	uint32_t version;
	uint32_t state_size;
	uint32_t max_machines;
	uint32_t max_vcpus;
	uint64_t max_ram;
	struct nvmm_cap_md arch;
};

/* Machine configuration slots. */
#define NVMM_MACH_CONF_LIBNVMM_BEGIN	0
#define NVMM_MACH_CONF_MI_BEGIN		100
#define NVMM_MACH_CONF_MD_BEGIN		200
#define NVMM_MACH_CONF_MD(op)		(op - NVMM_MACH_CONF_MD_BEGIN)

/* VCPU configuration slots. */
#define NVMM_VCPU_CONF_LIBNVMM_BEGIN	0
#define NVMM_VCPU_CONF_MI_BEGIN		100
#define NVMM_VCPU_CONF_MD_BEGIN		200
#define NVMM_VCPU_CONF_MD(op)		(op - NVMM_VCPU_CONF_MD_BEGIN)

struct nvmm_comm_page {
	/* State. */
	uint64_t state_wanted;
	uint64_t state_cached;
	uint64_t state_commit;
	struct nvmm_vcpu_state state;

	/* Event. */
	bool event_commit;
	struct nvmm_vcpu_event event;

	/* Race-free exit from nvmm_vcpu_run() without signals. */
	volatile int stop;
};

/*
 * Bits 20:27 -> machid
 * Bits 12:19 -> cpuid
 */
#define NVMM_COMM_OFF(machid, cpuid)	\
	((((uint64_t)machid & 0xFFULL) << 20) | (((uint64_t)cpuid & 0xFFULL) << 12))

#define NVMM_COMM_MACHID(off)		\
	((off >> 20) & 0xFF)

#define NVMM_COMM_CPUID(off)		\
	((off >> 12) & 0xFF)

#ifdef _KERNEL
/* At most one page, for the NVMM_COMM_* macros. */
CTASSERT(sizeof(struct nvmm_comm_page) <= PAGE_SIZE);
#endif

#endif