/* 	$NetBSD: cpuvar.h,v 1.53 2020/07/14 00:45:53 yamaguchi Exp $ */

/*-
 * Copyright (c) 2000, 2007 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by RedBack Networks Inc.
 *
 * Author: Bill Sommerfeld
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

/*
 * Copyright (c) 1999 Stefan Grefen
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
 *      This product includes software developed by the NetBSD
 *      Foundation, Inc. and its contributors.
 * 4. Neither the name of The NetBSD Foundation nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.  
 *
 * THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR AND CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _X86_CPUVAR_H_
#define	_X86_CPUVAR_H_

struct cpu_info;
struct cpu_functions {
#ifndef XENPV
	int (*start)(struct cpu_info *, paddr_t);
#else /* XENPV */
   	int (*start)(struct cpu_info *, vaddr_t);
#endif /* XENPV */
	int (*stop)(struct cpu_info *);
	void (*cleanup)(struct cpu_info *);
};

extern const struct cpu_functions mp_cpu_funcs;

#define CPU_ROLE_SP	0
#define CPU_ROLE_BP	1
#define CPU_ROLE_AP	2

struct cpu_attach_args {
	int cpu_id;
	int cpu_number;
	int cpu_role;
	const struct cpu_functions *cpu_func;
};

struct cpufeature_attach_args {
	struct cpu_info *ci;
	const char *name;
};

#ifdef _KERNEL
#include <sys/kcpuset.h>
#if defined(_KERNEL_OPT)
#include "opt_multiprocessor.h"
#include "opt_xen.h"
#endif /* defined(_KERNEL_OPT) */

extern int (*x86_ipi)(int, int, int);
int x86_ipi_init(int);
int x86_ipi_startup(int, int);
void x86_errata(void);

void identifycpu(struct cpu_info *);
void identifycpu_cpuids(struct cpu_info *);
void cpu_init(struct cpu_info *);
void cpu_init_tss(struct cpu_info *);
void cpu_init_first(void);
void cpu_init_idt(struct cpu_info *);

void x86_cpu_idle_init(void);
void x86_cpu_idle_halt(void);
void x86_cpu_idle_mwait(void);
#ifdef XEN
void x86_cpu_idle_xen(void);
#endif

void	cpu_get_tsc_freq(struct cpu_info *);
void	pat_init(struct cpu_info *);

extern int cpu_vendor;
extern bool x86_mp_online;

extern uint32_t cpu_feature[7];

#endif /* _KERNEL */

#endif /* !_X86_CPUVAR_H_ */