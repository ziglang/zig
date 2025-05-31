/*	$NetBSD: pset.h,v 1.7 2019/11/21 17:54:04 ad Exp $	*/

/*
 * Copyright (c) 2008, Mindaugas Rasiukevicius <rmind at NetBSD org>
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

#ifndef _SYS_PSET_H_
#define _SYS_PSET_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <sys/types.h>
#include <sys/idtype.h>

/* Types of processor-sets */
#define	PS_NONE			0
#define	PS_MYID			-1
#define	PS_QUERY		-2

__BEGIN_DECLS
int	pset_assign(psetid_t, cpuid_t, psetid_t *);
int	pset_bind(psetid_t, idtype_t, id_t, psetid_t *);
int	pset_create(psetid_t *);
int	pset_destroy(psetid_t);
__END_DECLS

#ifdef _NETBSD_SOURCE
int	_pset_bind(idtype_t, id_t, id_t, psetid_t, psetid_t *);
#endif	/* _NETBSD_SOURCE */

#ifdef _KERNEL

/* Processor-set structure */
typedef struct {
	int		ps_flags;
} pset_info_t;

void	psets_init(void);

#endif	/* _KERNEL */

#endif	/* _SYS_PSET_H_ */