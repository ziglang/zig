/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Justin Hibbits
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

#ifndef _SYS_ATOMIC64E_H_
#define _SYS_ATOMIC64E_H_

#ifndef _MACHINE_ATOMIC_H_
#error	"This should not be included directly.  Include <machine/atomic.h>"
#endif

#ifdef _KERNEL
#define	HAS_EMULATED_ATOMIC64

/* Emulated versions of 64-bit atomic operations. */

void	atomic_add_64(volatile u_int64_t *, u_int64_t);
#define	atomic_add_acq_64	atomic_add_64
#define	atomic_add_rel_64	atomic_add_64

int	atomic_cmpset_64(volatile u_int64_t *, u_int64_t, u_int64_t);
#define	atomic_cmpset_acq_64	atomic_cmpset_64
#define	atomic_cmpset_rel_64	atomic_cmpset_64

void	atomic_clear_64(volatile u_int64_t *, u_int64_t);
#define	atomic_clear_acq_64	atomic_clear_64
#define	atomic_clear_rel_64	atomic_clear_64

int	atomic_fcmpset_64(volatile u_int64_t *, u_int64_t *, u_int64_t);
#define	atomic_fcmpset_acq_64	atomic_fcmpset_64
#define	atomic_fcmpset_rel_64	atomic_fcmpset_64

u_int64_t atomic_fetchadd_64(volatile u_int64_t *, u_int64_t);

u_int64_t	atomic_load_64(volatile u_int64_t *);
#define	atomic_load_acq_64	atomic_load_64

void	atomic_readandclear_64(volatile u_int64_t *);

void	atomic_set_64(volatile u_int64_t *, u_int64_t);
#define	atomic_set_acq_64	atomic_set_64
#define	atomic_set_rel_64	atomic_set_64

void	atomic_subtract_64(volatile u_int64_t *, u_int64_t);
#define	atomic_subtract_acq_64	atomic_subtract_64
#define	atomic_subtract_rel_64	atomic_subtract_64

void	atomic_store_64(volatile u_int64_t *, u_int64_t);
#define	atomic_store_rel_64	atomic_store_64

u_int64_t atomic_swap_64(volatile u_int64_t *, u_int64_t);

#endif /* _KERNEL */
#endif /* _SYS_ATOMIC64E_H_ */