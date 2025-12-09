/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2025 James Gritton.
 * All rights reserved.
 *
 * This software was developed at the University of Cambridge Computer
 * Laboratory with support from a grant from Google, Inc.
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

#ifndef _SYS_JAILDESC_H_
#define	_SYS_JAILDESC_H_

#ifdef _KERNEL

#include <sys/queue.h>
#include <sys/selinfo.h>
#include <sys/_lock.h>
#include <sys/_mutex.h>
#include <sys/_types.h>

struct prison;

/*-
 * struct jaildesc describes a jail descriptor, which points to a struct
 * prison.  struct prison in turn has a linked list of struct jaildesc.
 *
 * Locking key:
 *   (c) set on creation, remains unchanged
 *   (d) jd_lock
 *   (p) jd_prison->pr_mtx
 */
struct jaildesc {
	LIST_ENTRY(jaildesc) jd_list;	/* (d,p) this prison's descs */
	struct prison	*jd_prison;	/* (d) the prison */
	struct mtx	 jd_lock;
	struct selinfo	 jd_selinfo;	/* (d) event notification */
	unsigned	 jd_flags;	/* (d) JDF_* flags */
};

/*
 * Locking macros for the jaildesc.
 */
#define	JAILDESC_LOCK_DESTROY(jd)	mtx_destroy(&(jd)->jd_lock)
#define	JAILDESC_LOCK_INIT(jd)		mtx_init(&(jd)->jd_lock, "jaildesc", \
					    NULL, MTX_DEF)
#define	JAILDESC_LOCK(jd)		mtx_lock(&(jd)->jd_lock)
#define	JAILDESC_UNLOCK(jd)		mtx_unlock(&(jd)->jd_lock)

/*
 * Flags for the jd_flags field
 */
#define	JDF_SELECTED	0x00000001	/* issue selwakeup() */
#define	JDF_REMOVED	0x00000002	/* jail was removed */
#define	JDF_OWNING	0x00000004	/* closing descriptor removes jail */

int jaildesc_find(struct thread *td, int fd, struct prison **prp,
    struct ucred **ucredp);
int jaildesc_alloc(struct thread *td, struct file **fpp, int *fdp, int owning);
void jaildesc_set_prison(struct file *jd, struct prison *pr);
void jaildesc_prison_cleanup(struct prison *pr);
void jaildesc_knote(struct prison *pr, long hint);

#endif /* _KERNEL */

#endif /* !_SYS_JAILDESC_H_ */