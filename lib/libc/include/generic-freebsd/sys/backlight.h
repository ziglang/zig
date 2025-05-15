/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 Emmanuel Vadot <manu@FreeBSD.org>
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

#ifndef __BACKLIGHT_H__
#define	__BACKLIGHT_H__

#include <sys/types.h>

#define	BACKLIGHTMAXLEVELS 100

struct backlight_props {
	uint32_t	brightness;
	uint32_t	nlevels;
	uint32_t	levels[BACKLIGHTMAXLEVELS];
};

enum backlight_info_type {
	BACKLIGHT_TYPE_PANEL = 0,
	BACKLIGHT_TYPE_KEYBOARD
};

#define	BACKLIGHTMAXNAMELENGTH	64

struct backlight_info {
	char				name[BACKLIGHTMAXNAMELENGTH];
	enum backlight_info_type	type;
};

/*
 * ioctls
 */

#define BACKLIGHTGETSTATUS	_IOWR('G', 0, struct backlight_props)
#define BACKLIGHTUPDATESTATUS	_IOWR('G', 1, struct backlight_props)
#define BACKLIGHTGETINFO	_IOWR('G', 2, struct backlight_info)

#endif	/* __BACKLIGHT_H__ */