/* $NetBSD: cpu_ucode.h,v 1.5 2022/09/15 14:34:22 msaitoh Exp $ */
/*
 * Copyright (c) 2012 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Christoph Egger.
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

#ifndef _X86_CPU_UCODE_H_
#define _X86_CPU_UCODE_H_

#define CPU_UCODE_LOADER_AMD 0
struct cpu_ucode_version_amd {
	uint64_t version;
};

#define CPU_UCODE_LOADER_INTEL1 1
struct cpu_ucode_version_intel1 {
	uint32_t ucodeversion;
	int platformid;
};

#ifdef _KERNEL
#include <sys/cpu.h>
#include <sys/cpuio.h>
#include <dev/firmload.h>

int cpu_ucode_amd_get_version(struct cpu_ucode_version *, void *, size_t);
int cpu_ucode_amd_firmware_open(firmware_handle_t *, const char *);
int cpu_ucode_amd_apply(struct cpu_ucode_softc *, int);

int cpu_ucode_intel_get_version(struct cpu_ucode_version *, void *, size_t);
int cpu_ucode_intel_firmware_open(firmware_handle_t *, const char *);
int cpu_ucode_intel_apply(struct cpu_ucode_softc *, int);
#endif /* _KERNEL */

struct intel1_ucode_header {
	uint32_t	uh_header_ver;
	uint32_t	uh_rev;
	uint32_t	uh_date;
	uint32_t	uh_signature;
	uint32_t	uh_checksum;
	uint32_t	uh_loader_rev;
	uint32_t	uh_proc_flags;
	uint32_t	uh_data_size;
	uint32_t	uh_total_size;
	uint32_t	uh_reserved[3];
};

struct intel1_ucode_ext_table {
	uint32_t	uet_count;
	uint32_t	uet_checksum;
	uint32_t	uet_reserved[3];
};

struct intel1_ucode_proc_signature {
	uint32_t	ups_signature;
	uint32_t	ups_proc_flags;
	uint32_t	ups_checksum;
};

#endif