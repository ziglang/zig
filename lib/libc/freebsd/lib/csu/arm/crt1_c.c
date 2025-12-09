/* LINTLIBRARY */
/*-
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright 2001 David E. O'Brien.
 * All rights reserved.
 * Copyright 1996-1998 John D. Polstra.
 * All rights reserved.
 * Copyright (c) 1997 Jason R. Thorpe.
 * Copyright (c) 1995 Christopher G. Demetriou
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *          This product includes software developed for the
 *          FreeBSD Project.  See https://www.freebsd.org/ for
 *          information about FreeBSD.
 *          This product includes software developed for the
 *          NetBSD Project.  See http://www.netbsd.org/ for
 *          information about NetBSD.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
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

#include <sys/param.h>
#include <sys/elf_common.h>

#include "libc_private.h"
#include "csu_common.h"

struct Struct_Obj_Entry;
struct ps_strings;

void _start(int, char **, char **, const struct Struct_Obj_Entry *,
    void (*)(void), struct ps_strings *) __dead2;

struct ps_strings *__ps_strings;

void __start(int, char **, char **, struct ps_strings *,
    const struct Struct_Obj_Entry *, void (*)(void)) __dead2;

void
__start(int argc, char **argv, char **env, struct ps_strings *ps_strings,
    const struct Struct_Obj_Entry *obj __unused, void (*cleanup)(void))
{
	if (ps_strings != (struct ps_strings *)0)
		__ps_strings = ps_strings;

#ifdef GCRT
	__libc_start1_gcrt(argc, argv, env, cleanup, main, &eprol, &etext);
#else
	__libc_start1(argc, argv, env, cleanup, main);
#endif
}

#ifdef GCRT
__asm__(".text");
__asm__("eprol:");
__asm__(".previous");
#endif
