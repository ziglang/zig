/*-
 * Copyright (c) 2013 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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
#include <sys/cdefs.h>
__RCSID("$NetBSD: crtbegin.c,v 1.17 2018/12/28 18:17:11 christos Exp $");

/* zig patch: no crtbegin.h */

typedef void (*fptr_t)(void);

/* zig patch: remove gcj nonsense */

#if !defined(HAVE_INITFINI_ARRAY)
extern __dso_hidden const fptr_t __CTOR_LIST__start __asm("__CTOR_LIST__");

__dso_hidden const fptr_t __aligned(sizeof(void *)) __CTOR_LIST__[] __section(".ctors") = {
	(fptr_t) -1,
};
__dso_hidden extern const fptr_t __CTOR_LIST_END__[];
#endif

#ifdef SHARED
__dso_hidden void *__dso_handle = &__dso_handle;

__weakref_visible void cxa_finalize(void *)
	__weak_reference(__cxa_finalize);
#else
__dso_hidden void *__dso_handle;
#endif

#if !defined(__ARM_EABI__) || defined(__ARM_DWARF_EH__)
__dso_hidden const long __EH_FRAME_LIST__[0] __section(".eh_frame");

__weakref_visible void register_frame_info(const void *, const void *)
	__weak_reference(__register_frame_info);
__weakref_visible void deregister_frame_info(const void *)
	__weak_reference(__deregister_frame_info);

static long dwarf_eh_object[8];
#endif

static void __do_global_ctors_aux(void) __used;

/* zig patch: use .init_array */
__attribute__((constructor))
static void
__do_global_ctors_aux(void)
{
	static unsigned char __initialized;

	if (__initialized)
		return;

	__initialized = 1;

#if !defined(__ARM_EABI__) || defined(__ARM_DWARF_EH__)
	if (register_frame_info)
		register_frame_info(__EH_FRAME_LIST__, &dwarf_eh_object);
#endif

    /* zig patch: remove gcj nonsense */

#if !defined(HAVE_INITFINI_ARRAY)
	for (const fptr_t *p = __CTOR_LIST_END__; p > &__CTOR_LIST__start + 1; ) {
		(*(*--p))();
	}
#endif
}

#if !defined(__ARM_EABI__) || defined(SHARED) || defined(__ARM_DWARF_EH__)
#if !defined(HAVE_INITFINI_ARRAY)
extern __dso_hidden const fptr_t __DTOR_LIST__start __asm("__DTOR_LIST__");

__dso_hidden const fptr_t __aligned(sizeof(void *)) __DTOR_LIST__[] __section(".dtors") = {
	(fptr_t) -1,
};
__dso_hidden extern const fptr_t __DTOR_LIST_END__[];
#endif

static void __do_global_dtors_aux(void) __used;

/* zig patch: use .fini_array */
__attribute__((destructor))
static void
__do_global_dtors_aux(void)
{
	static unsigned char __finished;

	if (__finished)
		return;

	__finished = 1;

#ifdef SHARED
	if (cxa_finalize)
		(*cxa_finalize)(__dso_handle);
#endif

#if !defined(HAVE_INITFINI_ARRAY)
	for (const fptr_t *p = &__DTOR_LIST__start + 1; p < __DTOR_LIST_END__; ) {
		(*(*p++))();
	}
#endif

#if !defined(__ARM_EABI__) || defined(__ARM_DWARF_EH__)
	if (deregister_frame_info)
		deregister_frame_info(__EH_FRAME_LIST__);
#endif
}
#endif /* !__ARM_EABI__ || SHARED || __ARM_DWARF_EH__ */
