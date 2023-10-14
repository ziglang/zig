/* Startup code compliant to the ELF RISC-V ABI.
   Copyright (C) 1995-2023 Free Software Foundation, Inc.
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

#define __ASSEMBLY__ 1
#include <entry.h>
#include <sysdep.h>
#include <sys/asm.h>

/* The entry point's job is to call __libc_start_main.  Per the ABI,
   a0 contains the address of a function to be passed to atexit.
   __libc_start_main wants this in a5.  */

ENTRY (ENTRY_POINT)
	/* Terminate call stack by noting ra is undefined.  Use a dummy
	   .cfi_label to force starting the FDE.  */
	.cfi_label .Ldummy
	cfi_undefined (ra)
	call  load_gp
	mv    a5, a0  /* rtld_fini.  */
	/* main may be in a shared library.  */
	la   a0, main
	REG_L a1, 0(sp)      /* argc.  */
	addi  a2, sp, SZREG  /* argv.  */
	andi  sp, sp, ALMASK /* Align stack. */
	li    a3, 0	     /* Used to be init.  */
	li    a4, 0	     /* Used to be fini.  */
	mv    a6, sp  /* stack_end.  */

	call  __libc_start_main@plt
	ebreak
END (ENTRY_POINT)

/* Dynamic links need the global pointer to be initialized prior to calling
   any shared library's initializers, so we use preinit_array to load it.
   This doesn't cut it for static links, though, since the global pointer
   needs to be initialized before calling __libc_start_main in that case.
   So we redundantly initialize it at the beginning of _start.  */

load_gp:
.option push
.option norelax
	lla   gp, __global_pointer$
.option pop
	ret

	.section .preinit_array,"aw"
	.dc.a load_gp

/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.weak data_start
	data_start = __data_start
