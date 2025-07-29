/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019, 2020 Jeffrey Roberson <jeff@FreeBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
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

#ifndef _SYS_SMR_TYPES_H_
#define	_SYS_SMR_TYPES_H_

#include <sys/_smr.h>

/*
 * SMR Accessors are meant to provide safe access to SMR protected
 * pointers and prevent misuse and accidental access.
 *
 * Accessors are grouped by type:
 * entered	- Use while in a read section (between smr_enter/smr_exit())
 * serialized 	- Use while holding a lock that serializes writers.   Updates
 *		  are synchronized with readers via included barriers.
 * unserialized	- Use after the memory is out of scope and not visible to
 *		  readers.
 *
 * All acceses include a parameter for an assert to verify the required
 * synchronization.  For example, a writer might use:
 *
 * smr_serialized_store(pointer, value, mtx_owned(&writelock));
 *
 * These are only enabled in INVARIANTS kernels.
 */

/* Type restricting pointer access to force smr accessors. */
#define	SMR_POINTER(type)						\
struct {								\
	type	__ptr;		/* Do not access directly */		\
}

/*
 * Read from an SMR protected pointer while in a read section.
 */
#define	smr_entered_load(p, smr) ({					\
	SMR_ASSERT(SMR_ENTERED((smr)), "smr_entered_load");		\
	(__typeof((p)->__ptr))atomic_load_acq_ptr((uintptr_t *)&(p)->__ptr); \
})

/*
 * Read from an SMR protected pointer while serialized by an
 * external mechanism.  'ex' should contain an assert that the
 * external mechanism is held.  i.e. mtx_owned()
 */
#define	smr_serialized_load(p, ex) ({					\
	SMR_ASSERT(ex, "smr_serialized_load");				\
	(__typeof((p)->__ptr))atomic_load_ptr(&(p)->__ptr);		\
})

/*
 * Store 'v' to an SMR protected pointer while serialized by an
 * external mechanism.  'ex' should contain an assert that the
 * external mechanism is held.  i.e. mtx_owned()
 *
 * Writers that are serialized with mutual exclusion or on a single
 * thread should use smr_serialized_store() rather than swap.
 */
#define	smr_serialized_store(p, v, ex) do {				\
	SMR_ASSERT(ex, "smr_serialized_store");				\
	__typeof((p)->__ptr) _v = (v);					\
	atomic_store_rel_ptr((uintptr_t *)&(p)->__ptr, (uintptr_t)_v);	\
} while (0)

/*
 * swap 'v' with an SMR protected pointer and return the old value
 * while serialized by an external mechanism.  'ex' should contain
 * an assert that the external mechanism is provided.  i.e. mtx_owned()
 *
 * Swap permits multiple writers to update a pointer concurrently.
 */
#define	smr_serialized_swap(p, v, ex) ({				\
	SMR_ASSERT(ex, "smr_serialized_swap");				\
	__typeof((p)->__ptr) _v = (v);					\
	/* Release barrier guarantees contents are visible to reader */ \
	atomic_thread_fence_rel();					\
	(__typeof((p)->__ptr))atomic_swap_ptr(				\
	    (uintptr_t *)&(p)->__ptr, (uintptr_t)_v);			\
})

/*
 * Read from an SMR protected pointer when no serialization is required
 * such as in the destructor callback or when the caller guarantees other
 * synchronization.
 */
#define	smr_unserialized_load(p, ex) ({					\
	SMR_ASSERT(ex, "smr_unserialized_load");			\
	(__typeof((p)->__ptr))atomic_load_ptr(&(p)->__ptr);		\
})

/*
 * Store to an SMR protected pointer when no serialiation is required
 * such as in the destructor callback or when the caller guarantees other
 * synchronization.
 */
#define	smr_unserialized_store(p, v, ex) do {				\
	SMR_ASSERT(ex, "smr_unserialized_store");			\
	__typeof((p)->__ptr) _v = (v);					\
	atomic_store_ptr((uintptr_t *)&(p)->__ptr, (uintptr_t)_v);	\
} while (0)

#ifndef _KERNEL

/*
 * Load an SMR protected pointer when accessing kernel data structures through
 * libkvm.
 */
#define	smr_kvm_load(p) ((p)->__ptr)

#endif /* !_KERNEL */
#endif /* !_SYS_SMR_TYPES_H_ */