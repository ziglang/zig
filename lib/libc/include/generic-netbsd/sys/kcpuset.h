/*	$NetBSD: kcpuset.h,v 1.11 2014/05/19 20:39:23 rmind Exp $	*/

/*-
 * Copyright (c) 2008, 2011 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Christos Zoulas and Mindaugas Rasiukevicius.
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

#ifndef	_SYS_KCPUSET_H_
#define	_SYS_KCPUSET_H_

struct kcpuset;
typedef struct kcpuset	kcpuset_t;

#ifdef _KERNEL

#include <sys/sched.h>

void		kcpuset_sysinit(void);

void		kcpuset_create(kcpuset_t **, bool);
void		kcpuset_clone(kcpuset_t **, const kcpuset_t *);
void		kcpuset_destroy(kcpuset_t *);
void		kcpuset_copy(kcpuset_t *, const kcpuset_t *);

void		kcpuset_use(kcpuset_t *);
void		kcpuset_unuse(kcpuset_t *, kcpuset_t **);

int		kcpuset_copyin(const cpuset_t *, kcpuset_t *, size_t);
int		kcpuset_copyout(kcpuset_t *, cpuset_t *, size_t);

void		kcpuset_zero(kcpuset_t *);
void		kcpuset_fill(kcpuset_t *);
void		kcpuset_set(kcpuset_t *, cpuid_t);
void		kcpuset_clear(kcpuset_t *, cpuid_t);

bool		kcpuset_isset(const kcpuset_t *, cpuid_t);
bool		kcpuset_isotherset(const kcpuset_t *, cpuid_t);
bool		kcpuset_iszero(const kcpuset_t *);
bool		kcpuset_intersecting_p(const kcpuset_t *, const kcpuset_t *);
bool		kcpuset_match(const kcpuset_t *, const kcpuset_t *);
void		kcpuset_intersect(kcpuset_t *, const kcpuset_t *);
void		kcpuset_merge(kcpuset_t *, const kcpuset_t *);
void		kcpuset_remove(kcpuset_t *, const kcpuset_t *);
int		kcpuset_countset(const kcpuset_t *);

cpuid_t		kcpuset_ffs(const kcpuset_t *);
cpuid_t		kcpuset_ffs_intersecting(const kcpuset_t *, const kcpuset_t *);

void		kcpuset_atomic_set(kcpuset_t *, cpuid_t);
void		kcpuset_atomic_clear(kcpuset_t *, cpuid_t);

void		kcpuset_atomicly_zero(kcpuset_t *);
void		kcpuset_atomicly_intersect(kcpuset_t *, const kcpuset_t *);
void		kcpuset_atomicly_merge(kcpuset_t *, const kcpuset_t *);
void		kcpuset_atomicly_remove(kcpuset_t *, const kcpuset_t *);

void		kcpuset_export_u32(const kcpuset_t *, uint32_t *, size_t);

#endif

#endif /* _SYS_KCPUSET_H_ */