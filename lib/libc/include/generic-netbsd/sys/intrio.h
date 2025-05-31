/*	$NetBSD: intrio.h,v 1.2 2016/08/03 08:25:38 knakahara Exp $	*/

/*
 * Copyright (c) 2015 Internet Initiative Japan Inc.
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

#ifndef _SYS_INTRIO_H_
#define _SYS_INTRIO_H_

#include <sys/types.h>
#include <sys/intr.h>
#include <sys/sched.h>

#define INTRIO_LIST_VERSION 1

struct intrio_set {
	char intrid[INTRIDBUF];
	cpuset_t *cpuset;
	size_t cpuset_size;
};

struct intrio_list_line_cpu {
	bool illc_assigned;
	uint64_t illc_count;
};

struct intrio_list_line {
	char ill_intrid[INTRIDBUF];		/* NUL terminated. */
	char ill_xname[INTRDEVNAMEBUF];		/* NUL terminated. */
	struct intrio_list_line_cpu ill_cpu[1];	/*
						 * Array size is overwritten
						 * to ncpu.
						 */
};

struct intrio_list {
	int il_version; /* Version number of this struct. */
	int il_ncpus;
	int il_nintrs;
	size_t il_bufsize;

	size_t il_linesize;
	off_t il_lineoffset;
/*
 * struct intrio_list_line il_lines[interrupt_num] must be followed here.
 */
};

#endif /* !_SYS_INTRIO_H_ */