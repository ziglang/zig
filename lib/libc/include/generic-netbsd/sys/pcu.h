/*	$NetBSD: pcu.h,v 1.14 2022/10/26 23:38:58 riastradh Exp $	*/

/*-
 * Copyright (c) 2011 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Mindaugas Rasiukevicius.
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

#ifndef _SYS_PCU_H_
#define _SYS_PCU_H_

#if !defined(_KERNEL) && !defined(_KMEMUSER)
#error "not supposed to be exposed to userland"
#endif

#ifndef _KERNEL
#include <stdbool.h>
#endif

/*
 * Default: no PCU for MD.
 */
#ifndef	PCU_UNIT_COUNT
#define	PCU_UNIT_COUNT		0
#endif

#if PCU_UNIT_COUNT > 0

/*
 * pcu_state_save(lwp)
 *	Tells MD code to save the current CPU's state into the given
 *	LWP's MD storage.
 *
 * pcu_state_load(lwp, flags)
 *	Tells MD code to load PCU state from the given LWP's MD storage
 *	to the current CPU.
 *
 * pcu_state_release(lwp)
 *	Tells MD code detect the next use of the PCU on the LWP and
 *	call pcu_load().
 */

typedef struct {
	u_int	pcu_id;
	void	(*pcu_state_save)(lwp_t *);
	void	(*pcu_state_load)(lwp_t *, unsigned);
	void	(*pcu_state_release)(lwp_t *);
} pcu_ops_t;

/*
 * Flags for the pcu_state_load() operation.
 */
#define	PCU_VALID	0x01	/* PCU state is considered valid */
#define	PCU_REENABLE	0x02	/* the state is present, re-enable PCU */

void	pcu_switchpoint(lwp_t *);
void	pcu_discard_all(lwp_t *);
void	pcu_save_all(lwp_t *);

void	pcu_load(const pcu_ops_t *);
void	pcu_save(const pcu_ops_t *, lwp_t *);
void	pcu_save_all_on_cpu(void);
void	pcu_discard(const pcu_ops_t *, lwp_t *, bool);
bool	pcu_valid_p(const pcu_ops_t *, const lwp_t *);

/* PCU operations structure provided by the MD code. */
extern const pcu_ops_t *const pcu_ops_md_defs[];

#else
#define	pcu_switchpoint(l)
#define	pcu_discard_all(l)
#define	pcu_save_all(l)
#endif

#endif