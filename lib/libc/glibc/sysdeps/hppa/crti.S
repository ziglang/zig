/* Special .init and .fini section support for HPPA
   Copyright (C) 2000-2024 Free Software Foundation, Inc.
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

In a final executable, PLABEL32 relocations for function pointers are
resolved at link time.  Typically, binutils/ld resolves __gmon_start__
using an external shared library.  __gmon_start__ is always called if
it is found at link time.  If __gmon_start__ is not found at runtime
due to a library update, then the function pointer will point at a null
function descriptor and calling it will cause a segmentation fault.
So, we call __canonicalize_funcptr_for_compare to obtain the canonicalized
address of __gmon_start__ and skip calling __gmon_start__ if it is zero.

 */
	.type __canonicalize_funcptr_for_compare,@function
	.type $$dyncall,@function

	.section .data.rel.ro,"aw",@progbits
	.align 4
.LC0:
	.type __gmon_start__,@function
	.word P%__gmon_start__

	.text
	.align 4
	.type gmon_initializer,@function
gmon_initializer:
	.PROC
	.CALLINFO FRAME=64,CALLS,SAVE_RP,ENTRY_GR=4
	.ENTRY
	stw %r2,-20(%r30)
	stwm %r4,64(%r30)
	stw %r3,-60(%r30)
	addil LT'.LC0,%r19
	ldw RT'.LC0(%r1),%r28
	ldw 0(%r28),%r3
	comib,= 0,%r3,1f
	copy %r19,%r4
	stw %r19,-32(%r30)
	bl __canonicalize_funcptr_for_compare,%r2
	copy %r3,%r26
	comib,= 0,%r28,1f
	copy %r4,%r19
	copy %r3,%r22
	.CALL ARGW0=GR
	bl $$dyncall,%r31
	copy %r31,%r2
1:
	ldw -84(%r30),%r2
	ldw -60(%r30),%r3
	bv %r0(%r2)
	ldwm -64(%r30),%r4
	.EXIT
	.PROCEND
	.size gmon_initializer, .-gmon_initializer

# undef PREINIT_FUNCTION
# define PREINIT_FUNCTION gmon_initializer
#endif

	.section .init_array, "aw"
	.word P% PREINIT_FUNCTION


/* _init prologue.  */
	.section .init, "ax", %progbits
	.align 4
	.globl _init
	.hidden	_init
	.type _init,@function
_init:
	stw	%rp,-20(%sp)
	stwm	%r4,64(%sp)
	stw	%r19,-32(%sp)

/* _fini prologue.  */
        .section .fini,"ax",%progbits
	.align 4
	.globl _fini
	.hidden	_fini
	.type _fini,@function
_fini:
	stw	%rp,-20(%sp)
	stwm	%r4,64(%sp)
	stw	%r19,-32(%sp)
	copy	%r19,%r4
