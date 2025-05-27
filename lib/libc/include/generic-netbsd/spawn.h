/*	$NetBSD: spawn.h,v 1.5 2021/11/07 14:34:30 christos Exp $	*/

/*-
 * Copyright (c) 2008 Ed Schouten <ed@FreeBSD.org>
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
 *
 * $FreeBSD: src/include/spawn.h,v 1.3.2.1.4.1 2010/06/14 02:09:06 kensmith Exp $
 */

#ifndef _SPAWN_H
#define _SPAWN_H

#include <sys/spawn.h>

__BEGIN_DECLS
/*
 * Spawn routines
 *
 */
int posix_spawn(pid_t * __restrict, const char * __restrict,
    const posix_spawn_file_actions_t *, const posix_spawnattr_t * __restrict,
    char * const *__restrict, char * const *__restrict);
int posix_spawnp(pid_t * __restrict, const char * __restrict,
    const posix_spawn_file_actions_t *, const posix_spawnattr_t * __restrict,
    char * const *__restrict, char * const *__restrict);

/*
 * File descriptor actions
 */
int posix_spawn_file_actions_init(posix_spawn_file_actions_t *);
int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *);

int posix_spawn_file_actions_addopen(posix_spawn_file_actions_t * __restrict,
    int, const char * __restrict, int, mode_t);
int posix_spawn_file_actions_adddup2(posix_spawn_file_actions_t *, int, int);
int posix_spawn_file_actions_addclose(posix_spawn_file_actions_t *, int);

int posix_spawn_file_actions_addchdir(posix_spawn_file_actions_t * __restrict,
        const char * __restrict);
int posix_spawn_file_actions_addfchdir(posix_spawn_file_actions_t *, int);

/*
 * Spawn attributes
 */
int posix_spawnattr_init(posix_spawnattr_t *);
int posix_spawnattr_destroy(posix_spawnattr_t *);

int posix_spawnattr_getflags(const posix_spawnattr_t * __restrict,
    short * __restrict);
int posix_spawnattr_getpgroup(const posix_spawnattr_t * __restrict,
    pid_t * __restrict);
int posix_spawnattr_getschedparam(const posix_spawnattr_t * __restrict,
    struct sched_param * __restrict);
int posix_spawnattr_getschedpolicy(const posix_spawnattr_t * __restrict,
    int * __restrict);
int posix_spawnattr_getsigdefault(const posix_spawnattr_t * __restrict,
    sigset_t * __restrict);
int posix_spawnattr_getsigmask(const posix_spawnattr_t * __restrict,
    sigset_t * __restrict sigmask);

int posix_spawnattr_setflags(posix_spawnattr_t *, short);
int posix_spawnattr_setpgroup(posix_spawnattr_t *, pid_t);
int posix_spawnattr_setschedparam(posix_spawnattr_t * __restrict,
    const struct sched_param * __restrict);
int posix_spawnattr_setschedpolicy(posix_spawnattr_t *, int);
int posix_spawnattr_setsigdefault(posix_spawnattr_t * __restrict,
    const sigset_t * __restrict);
int posix_spawnattr_setsigmask(posix_spawnattr_t * __restrict,
    const sigset_t * __restrict);
__END_DECLS

#endif /* _SPAWN_H */