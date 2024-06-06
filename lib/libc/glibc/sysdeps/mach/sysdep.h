/* Copyright (C) 1994-2024 Free Software Foundation, Inc.
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

#ifdef __ASSEMBLER__

/* Get the Mach definitions of ENTRY and kernel_trap.  */
#include <mach/machine/syscall_sw.h>

/* The Mach definitions assume underscores should be prepended to
   symbol names.  Redefine them to do so only when appropriate.  */
#undef EXT
#undef LEXT
#define EXT(x) C_SYMBOL_NAME(x)
#define LEXT(x) C_SYMBOL_NAME(x##:)

/* For ELF we need to add the `.type' directive to make shared libraries
   work right.  */
#undef ENTRY
#undef ENTRY2
#define ENTRY(name) \
  .globl name; \
  .align ALIGN; \
  .type name,@function; \
  name:

#endif

/* This is invoked by things run when there is random lossage, before they
   try to do anything else.  Just to be safe, deallocate the reply port so
   bogons arriving on it don't foul up future RPCs.  */

#ifndef __ASSEMBLER__
#define FATAL_PREPARE_INCLUDE <mach/mig_support.h>
#define FATAL_PREPARE __mig_dealloc_reply_port (__mig_get_reply_port ())
#endif

/* sysdeps/mach/MACHINE/sysdep.h should define the following macros.  */

/* Produce a text assembler label for the C global symbol NAME.  */
#ifndef ENTRY
#define ENTRY(name) .error ENTRY not defined by sysdeps/mach/MACHINE/sysdep.h
/* This is not used on all machines.  */
#endif

/* LOSE can be defined as the `halt' instruction or something
   similar which will cause the process to die in a characteristic
   way suggesting a bug.  */
#ifndef LOSE
#define	LOSE	({ volatile int zero = 0; zero / zero; })
#endif

/* One of these should be defined to specify the stack direction.  */
#if !defined (STACK_GROWTH_UP) && !defined (STACK_GROWTH_DOWN)
#error stack direction unspecified
#endif

/* Used by some assembly code.  */
#define C_SYMBOL_NAME(name)	name
