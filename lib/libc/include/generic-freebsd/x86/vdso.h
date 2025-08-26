/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright 2012 Konstantin Belousov <kib@FreeBSD.ORG>.
 * Copyright 2016 The FreeBSD Foundation.
 * All rights reserved.
 *
 * Portions of this software were developed by Konstantin Belousov
 * under sponsorship from the FreeBSD Foundation.
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

#ifndef _X86_VDSO_H
#define	_X86_VDSO_H

#define	VDSO_TIMEHANDS_MD			\
	uint32_t	th_x86_shift;		\
	uint32_t	th_x86_hpet_idx;	\
	uint64_t	th_x86_pvc_last_systime;\
	uint8_t		th_x86_pvc_stable_mask;	\
	uint8_t		th_res[15];

#define	VDSO_TH_ALGO_X86_TSC	VDSO_TH_ALGO_1
#define	VDSO_TH_ALGO_X86_HPET	VDSO_TH_ALGO_2
#define	VDSO_TH_ALGO_X86_HVTSC	VDSO_TH_ALGO_3	/* Hyper-V ref. TSC */
#define	VDSO_TH_ALGO_X86_PVCLK	VDSO_TH_ALGO_4	/* KVM/XEN paravirtual clock */

#ifdef _KERNEL
#ifdef COMPAT_FREEBSD32

#define	VDSO_TIMEHANDS_MD32			\
	uint32_t	th_x86_shift;		\
	uint32_t	th_x86_hpet_idx;	\
	uint32_t	th_x86_pvc_last_systime[2];\
	uint8_t		th_x86_pvc_stable_mask;	\
	uint8_t		th_res[15];

#endif
#endif
#endif