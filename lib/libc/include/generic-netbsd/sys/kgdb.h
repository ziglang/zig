/*	$NetBSD: kgdb.h,v 1.12 2011/04/03 22:29:28 dyoung Exp $	*/

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratories.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)remote-sl.h	8.1 (Berkeley) 6/11/93
 */

#ifndef _SYS_KGDB_H_
#define _SYS_KGDB_H_

/*
 * Protocol definition for KGDB
 * (gdb over remote serial line)
 */

#include <machine/db_machdep.h>

/*
 * Message types.
 */
#define KGDB_MEM_R	'm'
#define KGDB_MEM_W	'M'
#define KGDB_REG_R	'g'
#define KGDB_REG_W	'G'
#define KGDB_CONT	'c'
#define KGDB_STEP	's'
#define KGDB_KILL	'k'
#define KGDB_DETACH	'D'
#define KGDB_SIGNAL	'?'
#define KGDB_DEBUG	'd'

/*
 * start of frame/end of frame
 */
#define KGDB_START	'$'
#define KGDB_END	'#'
#define KGDB_GOODP	'+'
#define KGDB_BADP	'-'

#ifdef	_KERNEL

#include <ddb/db_run.h>
#include <ddb/db_access.h>

/*
 * Functions and variables exported from kgdb_stub.c
 */
extern dev_t kgdb_dev;
extern int kgdb_rate, kgdb_active;
extern int kgdb_debug_init, kgdb_debug_panic;
extern label_t *kgdb_recover;

void kgdb_attach(int (*)(void *), void (*)(void *, int), void *);
void kgdb_connect(int);
void kgdb_panic(void);
int kgdb_trap(int, db_regs_t *);
int kgdb_disconnected(void);

/*
 * Machine dependent functions needed by kgdb_stub.c
 */
int kgdb_signal(int);
int kgdb_acc(vaddr_t, size_t);
void kgdb_entry_notice(int, db_regs_t *);
void kgdb_getregs(db_regs_t *, kgdb_reg_t *);
void kgdb_setregs(db_regs_t *, kgdb_reg_t *);

#endif	/* _KERNEL */
#endif /* !_SYS_KGDB_H_ */