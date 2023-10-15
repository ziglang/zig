/* Macros for defining Systemtap <sys/sdt.h> static probe points.
   Copyright (C) 2012-2023 Free Software Foundation, Inc.
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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _STAP_PROBE_H
#define _STAP_PROBE_H 1

#ifdef USE_STAP_PROBE

# include <stap-probe-machine.h>
# include <sys/sdt.h>

/* Our code uses one macro LIBC_PROBE (name, n, arg1, ..., argn).

   Without USE_STAP_PROBE, that does nothing but evaluates all
   its arguments (to prevent bit rot, unlike e.g. assert).

   Systemtap's header defines the macros STAP_PROBE (provider, name) and
   STAP_PROBEn (provider, name, arg1, ..., argn).  For "provider" we paste
   in MODULE_NAME (libc, libpthread, etc.) automagically.

   The format of the arg parameters is discussed here:

   https://sourceware.org/systemtap/wiki/UserSpaceProbeImplementation

   The precise details of how register names are specified is
   architecture specific and can be found in the gdb and SystemTap
   source code.  */

# define LIBC_PROBE(name, n, ...)	\
  LIBC_PROBE_1 (MODULE_NAME, name, n, ## __VA_ARGS__)

# define LIBC_PROBE_1(lib, name, n, ...) \
  STAP_PROBE##n (lib, name, ## __VA_ARGS__)

# define STAP_PROBE0		STAP_PROBE

# define LIBC_PROBE_ASM(name, template) \
  STAP_PROBE_ASM (MODULE_NAME, name, template)

# define LIBC_PROBE_ASM_OPERANDS STAP_PROBE_ASM_OPERANDS

#else  /* Not USE_STAP_PROBE.  */

# ifndef __ASSEMBLER__
/* Evaluate all the arguments and verify that N matches their number.  */
#  define LIBC_PROBE(name, n, ...) STAP_PROBE##n (__VA_ARGS__)

#  define STAP_PROBE0()				do {} while (0)
#  define STAP_PROBE1(a1)			do {} while (0)
#  define STAP_PROBE2(a1, a2)			do {} while (0)
#  define STAP_PROBE3(a1, a2, a3)		do {} while (0)
#  define STAP_PROBE4(a1, a2, a3, a4)		do {} while (0)

# else
#  define LIBC_PROBE(name, n, ...)		/* Nothing.  */
# endif

# define LIBC_PROBE_ASM(name, template)		/* Nothing.  */
# define LIBC_PROBE_ASM_OPERANDS(n, ...)	/* Nothing.  */

#endif	/* USE_STAP_PROBE.  */

#endif	/* stap-probe.h */
