/* $NetBSD: keylock.h,v 1.1 2009/08/15 09:43:58 mbalmer Exp $ */

/*
 * Copyright (c) 2009 Marc Balmer <marc@msys.ch>
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

#ifndef _SYS_KEYLOCK_H
#define _SYS_KEYLOCK_H

#define KEYLOCK_ABSENT          0
#define KEYLOCK_TAMPER          1
#define KEYLOCK_OPEN            2
#define KEYLOCK_SEMIOPEN        3
#define KEYLOCK_SEMICLOSE	4
#define KEYLOCK_CLOSE           5

#ifdef _KERNEL
/* Functions for keylock drivers */
extern int keylock_register(void *, int, int (*)(void *));
extern void keylock_unregister(void *, int (*)(void *));

/* Functions to query the keylock state */
extern int keylock_state(void);
extern int keylock_position(void);
extern int keylock_num_positions(void);
#endif

#endif /* _SYS_KEYLOCK_H */