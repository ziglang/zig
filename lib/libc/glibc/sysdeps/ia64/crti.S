/* Special .init and .fini section support for IA64.
   Copyright (C) 2000-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   In addition to the permissions in the GNU Lesser General Public
   License, the Free Software Foundation gives you unlimited
   permission to link the compiled version of this file with other
   programs, and to distribute those programs without any restriction
   coming from the use of this file. (The GNU Lesser General Public
   License restrictions do apply in other respects; for example, they
   cover modification of the file, and distribution when not linked
   into another program.)

   Note that people who make modified versions of this file are not
   obligated to grant this special exception for their modified
   versions; it is their choice whether to do so. The GNU Lesser
   General Public License gives permission to release a modified
   version without this exception; this exception also makes it
   possible to release a modified version which carries forward this
   exception.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

/* crti.S puts a function prologue at the beginning of the .init and
   .fini sections and defines global symbols for those addresses, so
   they can be called as functions.  The symbols _init and _fini are
   magic and cause the linker to emit DT_INIT and DT_FINI.  */

#include <libc-symbols.h>
#include <sysdep.h>
#undef ret

#ifndef PREINIT_FUNCTION
# define PREINIT_FUNCTION __gmon_start__
#endif

#ifndef PREINIT_FUNCTION_WEAK
# define PREINIT_FUNCTION_WEAK 1
#endif

#if PREINIT_FUNCTION_WEAK
	weak_extern (PREINIT_FUNCTION)
#else
	.hidden PREINIT_FUNCTION
#endif

/* If we have working .init_array support, we want to keep the .init
   section empty (apart from the mandatory prologue/epilogue.  This
   ensures that the default unwind conventions (return-pointer in b0,
   frame state in ar.pfs, etc.)  will do the Right Thing.  To ensure
   an empty .init section, we register gmon_initializer() via the
   .init_array.

    --davidm 02/10/29 */

#if PREINIT_FUNCTION_WEAK
/* This blob of assembly code is one simple C function:

static void
__attribute__ ((used))
gmon_initializer (void)
{
  extern void weak_function __gmon_start__ (void);

  if (__gmon_start__)
    (*__gmon_start__)();
}
 */
	.text
	.align 64
	.proc gmon_initializer#
gmon_initializer:
	.prologue 12, 32
	.mmi
	.save ar.pfs, r33
	alloc r33 = ar.pfs, 0, 3, 0, 0
	addl r14 = @ltoff(@fptr(PREINIT_FUNCTION#)), gp
	.save rp, r32
	mov r32 = b0
	.mmi
	mov r34 = r1
	.body
	;;
	ld8 r14 = [r14]
	nop 0
	;;
	.mib
	cmp.eq p6, p7 = 0, r14
	nop 0
	(p6) br.cond.spnt .L1
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = PREINIT_FUNCTION#
	;;
	.mmi
	mov r1 = r34
	nop 0
	nop 0
.L1:
	.mii
	nop 0
	mov ar.pfs = r33
	nop 0
	;;
	.mib
	nop 0
	mov b0 = r32
	br.ret.sptk.many b0
	.endp gmon_initializer#
# undef PREINIT_FUNCTION
# define PREINIT_FUNCTION gmon_initializer
#endif
	.section .init_array, "aw"
	data8 @fptr(PREINIT_FUNCTION)

	.section .init,"ax",@progbits
	.global _init#
	.hidden	_init#
	.proc _init#
_init:
	.prologue
	.save ar.pfs, r34
	alloc r34 = ar.pfs, 0, 3, 0, 0
	.vframe r32
	mov r32 = r12
	.save rp, r33
	mov r33 = b0
	.body
	adds r12 = -16, r12
	;;		/* see gmon_initializer() above */
	.endp _init#

	.section .fini,"ax",@progbits
	.global _fini#
	.hidden	_fini#
	.proc _fini#
_fini:
	.prologue
	.save ar.pfs, r34
	alloc r34 = ar.pfs, 0, 3, 0, 0
	.vframe r32
	mov r32 = r12
	.save rp, r33
	mov r33 = b0
	.body
	adds r12 = -16, r12
	;;
	.endp _fini#
