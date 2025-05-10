/*	$NetBSD: csan.h,v 1.2 2019/11/06 06:57:22 maxv Exp $	*/

/*
 * Copyright (c) 2019 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Maxime Villard.
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

#include <sys/timetc.h>

#include <machine/clock.h>
#include <machine/cpufunc.h>
#include <machine/stack.h>
#include <machine/vmparam.h>

static inline bool
kcsan_md_unsupported(vm_offset_t addr)
{
	return false;
}

static inline bool
kcsan_md_is_avail(void)
{
	return true;
}

static inline void
kcsan_md_disable_intrs(uint64_t *state)
{

	*state = intr_disable();
}

static inline void
kcsan_md_enable_intrs(uint64_t *state)
{

	intr_restore(*state);
}

static inline void
kcsan_md_delay(uint64_t us)
{
	/*
	 * Only call DELAY if not using the early delay code. The i8254
	 * early delay function may cause us to recurse on a spin lock
	 * leading to a panic.
	 */
	if ((tsc_is_invariant && tsc_freq != 0) ||
	    timecounter->tc_quality > 0)
		DELAY(us);
}

static void
kcsan_md_unwind(void)
{
}