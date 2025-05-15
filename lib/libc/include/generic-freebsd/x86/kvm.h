/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2014 Bryan Venteicher <bryanv@FreeBSD.org>
 * Copyright (c) 2021 Mathieu Chouquet-Stringer
 * Copyright (c) 2021 Juniper Networks, Inc.
 * Copyright (c) 2021 Klara, Inc.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * Linux KVM paravirtualization: common definitions
 *
 * References:
 *     - [1] https://www.kernel.org/doc/html/latest/virt/kvm/cpuid.html
 *     - [2] https://www.kernel.org/doc/html/latest/virt/kvm/msr.html
 */

#ifndef _X86_KVM_H_
#define	_X86_KVM_H_

#include <sys/types.h>
#include <sys/systm.h>

#include <machine/md_var.h>

#define	KVM_CPUID_SIGNATURE			0x40000000
#define	KVM_CPUID_FEATURES_LEAF			0x40000001

#define	KVM_FEATURE_CLOCKSOURCE			0x00000001
#define	KVM_FEATURE_CLOCKSOURCE2		0x00000008
#define	KVM_FEATURE_CLOCKSOURCE_STABLE_BIT	0x01000000

/* Deprecated: for the CLOCKSOURCE feature. */
#define	KVM_MSR_WALL_CLOCK			0x11
#define	KVM_MSR_SYSTEM_TIME			0x12

#define	KVM_MSR_WALL_CLOCK_NEW			0x4b564d00
#define	KVM_MSR_SYSTEM_TIME_NEW			0x4b564d01

static inline bool
kvm_cpuid_features_leaf_supported(void)
{
	return (vm_guest == VM_GUEST_KVM &&
	    KVM_CPUID_FEATURES_LEAF > hv_base &&
	    KVM_CPUID_FEATURES_LEAF <= hv_high);
}

static inline void
kvm_cpuid_get_features(u_int *regs)
{
	if (!kvm_cpuid_features_leaf_supported())
		regs[0] = regs[1] = regs[2] = regs[3] = 0;
	else
		do_cpuid(KVM_CPUID_FEATURES_LEAF, regs);
}

#endif /* !_X86_KVM_H_ */