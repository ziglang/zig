/*	$NetBSD: hook.h,v 1.1 2021/09/30 01:26:07 yamaguchi Exp $	*/

/*
 * Copyright (c) 2021 Internet Initiative Japan Inc.
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

#ifndef _SYS_HOOK_H_
#define _SYS_HOOK_H_

#include <sys/mutex.h>

#define HOOKNAMSIZ	128

struct khook_list;
struct hook_desc;

typedef struct khook_list	khook_list_t;
typedef struct hook_desc	khook_t;

khook_list_t	*simplehook_create(int, const char *);
void		 simplehook_destroy(khook_list_t *);
int		 simplehook_dohooks(khook_list_t *);

khook_t		*simplehook_establish(khook_list_t *,
		    void (*)(void *), void *);
void		 simplehook_disestablish(khook_list_t *,
		    khook_t *, kmutex_t *);
bool		 simplehook_has_hooks(khook_list_t *);

#endif /* !_SYS_HOOK_H_ */