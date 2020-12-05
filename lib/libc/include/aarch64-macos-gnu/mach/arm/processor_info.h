/*
 * Copyright (c) 2007-2018 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */

#ifndef _MACH_ARM_PROCESSOR_INFO_H_
#define _MACH_ARM_PROCESSOR_INFO_H_

#define PROCESSOR_CPU_STAT   0x10000003 /* Low-level CPU statistics */
#define PROCESSOR_CPU_STAT64 0x10000004 /* Low-level CPU statistics, in full 64-bit */

#include <stdint.h> /* uint32_t, uint64_t */

struct processor_cpu_stat {
	uint32_t irq_ex_cnt;
	uint32_t ipi_cnt;
	uint32_t timer_cnt;
	uint32_t undef_ex_cnt;
	uint32_t unaligned_cnt;
	uint32_t vfp_cnt;
	uint32_t vfp_shortv_cnt;
	uint32_t data_ex_cnt;
	uint32_t instr_ex_cnt;
};

typedef struct processor_cpu_stat  processor_cpu_stat_data_t;
typedef struct processor_cpu_stat *processor_cpu_stat_t;
#define PROCESSOR_CPU_STAT_COUNT ((mach_msg_type_number_t) \
	        (sizeof(processor_cpu_stat_data_t) / sizeof(natural_t)))

struct processor_cpu_stat64 {
	uint64_t irq_ex_cnt;
	uint64_t ipi_cnt;
	uint64_t timer_cnt;
	uint64_t undef_ex_cnt;
	uint64_t unaligned_cnt;
	uint64_t vfp_cnt;
	uint64_t vfp_shortv_cnt;
	uint64_t data_ex_cnt;
	uint64_t instr_ex_cnt;
	uint64_t pmi_cnt;
} __attribute__((packed, aligned(4)));

typedef struct processor_cpu_stat64  processor_cpu_stat64_data_t;
typedef struct processor_cpu_stat64 *processor_cpu_stat64_t;
#define PROCESSOR_CPU_STAT64_COUNT ((mach_msg_type_number_t) \
	        (sizeof(processor_cpu_stat64_data_t) / sizeof(integer_t)))

#endif /* _MACH_ARM_PROCESSOR_INFO_H_ */
