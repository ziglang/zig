/*	$NetBSD: wsksymvar.h,v 1.11 2008/04/28 20:24:01 martin Exp $ */

/*-
 * Copyright (c) 1997 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Juergen Hannken-Illjes.
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

#ifndef _DEV_WSCONS_WSKSYMVAR_H_
#define _DEV_WSCONS_WSKSYMVAR_H_

#ifndef _KERNEL
#include <sys/types.h>
#endif

typedef u_int16_t keysym_t;
typedef u_int32_t kbd_t;

struct wscons_keymap {
	keysym_t command;
	keysym_t group1[2];
	keysym_t group2[2];
};

#ifdef _KERNEL
struct wscons_keydesc {
	kbd_t	name;				/* name of this map */
	kbd_t	base;				/* map this one is based on */
	int	map_size;			/* size of map */
	const keysym_t *map;			/* the map itself */
};

struct wskbd_mapdata {
	const struct wscons_keydesc *keydesc;
	kbd_t layout;
};

/* layout variant bits ignored by mapping code */
#define KB_HANDLEDBYWSKBD KB_METAESC

/*
 * Utility functions.
 */
void	wskbd_get_mapentry(const struct wskbd_mapdata *, int,
			   struct wscons_keymap *);
void	wskbd_init_keymap(int, struct wscons_keymap **, int *);
int	wskbd_load_keymap(const struct wskbd_mapdata *,
                          struct wscons_keymap **, int *);
keysym_t wskbd_compose_value(keysym_t *);

#endif

#endif /* !_DEV_WSCONS_WSKSYMVAR_H_ */