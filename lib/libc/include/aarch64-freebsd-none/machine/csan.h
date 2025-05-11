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
	DELAY(us);
}

static void
kcsan_md_unwind(void)
{
#ifdef DDB
	c_db_sym_t sym;
	db_expr_t offset;
	const char *symname;
#endif
	struct unwind_state frame;
	int nsym;

	frame.fp = (uintptr_t)__builtin_frame_address(0);
	frame.pc = (uintptr_t)kcsan_md_unwind;
	nsym = 0;

	while (1) {
		if (!unwind_frame(curthread, &frame))
			break;
		if (!INKERNEL((vm_offset_t)frame.pc))
			break;

#ifdef DDB
		sym = db_search_symbol((vm_offset_t)frame.pc, DB_STGY_PROC,
		    &offset);
		db_symbol_values(sym, &symname, NULL);
		printf("#%d %p in %s+%#lx\n", nsym, (void *)frame.pc,
		    symname, offset);
#else
		printf("#%d %p\n", nsym, (void *)frame.pc);
#endif
		nsym++;

		if (nsym >= 15) {
			break;
		}
	}
}