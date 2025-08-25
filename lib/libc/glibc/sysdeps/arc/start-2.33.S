/* Startup code for ARC.
   Copyright (C) 2020-2021 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#define __ASSEMBLY__ 1
#include <entry.h>
#include <sysdep.h>

#ifndef ENTRY_POINT
# error ENTRY_POINT needs to be defined for ARC
#endif

/* When we enter this piece of code, the program stack looks like this:
        argc            argument counter (integer)
        argv[0]         program name (pointer)
        argv[1...N]     program args (pointers)
        argv[argc-1]    end of args (integer)
        NULL
        env[0...N]      environment variables (pointers)
        NULL.  */

ENTRY (ENTRY_POINT)

	/* Needed to make gdb backtraces stop here.  */
	.cfi_label .Ldummy
	cfi_undefined (blink)

	mov	fp, 0
	ld_s	r1, [sp]	/* argc.  */

	mov_s	r5, r0		/* rltd_fini.  */
	add_s	r2, sp, 4	/* argv.  */
	and	sp, sp, -8
	mov	r6, sp

	/* __libc_start_main (main, argc, argv, init, fini, rtld_fini, stack_end).  */

#ifdef SHARED
	ld	r0, [pcl, @main@gotpc]
	ld	r3, [pcl, @__libc_csu_init@gotpc]
	ld	r4, [pcl, @__libc_csu_fini@gotpc]
	bl	__libc_start_main@plt
#else
	mov_s	r0, main
	mov_s	r3, __libc_csu_init
	mov	r4, __libc_csu_fini
	bl	__libc_start_main
#endif

	/* Should never get here.  */
	flag    1
END (ENTRY_POINT)

/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.long 0
	.weak data_start
	data_start = __data_start
