/* Copyright (C) 1997-2024 Free Software Foundation, Inc.

   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public License as
   published by the Free Software Foundation; either version 2.1 of the
   License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#include <sysdeps/generic/sysdep.h>

#ifdef  __ASSEMBLER__

/* Syntactic details of assembler.  */

# define ALIGNARG(log2) log2
# define ASM_SIZE_DIRECTIVE(name) .size name,.-name

/* Define an entry point visible from C.  */
# define ENTRY(name)                          \
  .globl C_SYMBOL_NAME(name);                 \
  .type C_SYMBOL_NAME(name),@function;        \
  .align ALIGNARG(2);                         \
  C_LABEL(name)                               \
  CALL_MCOUNT

# undef END
# define END(name) ASM_SIZE_DIRECTIVE(name)


/* If compiled for profiling, call `_mcount' at the start of each function.  */
# ifdef  PROF
/* The mcount code relies on a normal frame pointer being on the stack
   to locate our caller, so push one just for its benefit.  */
#  define CALL_MCOUNT                         \
   addik r1,r1,-4;                            \
   swi r15,r1,0;                              \
   brlid r15,JUMPTARGET(mcount);              \
   nop;                                       \
   lwi r15,r1,0;                              \
   addik r1,r1,4;
# else
#  define CALL_MCOUNT        /* Do nothing.  */
# endif

/* Since C identifiers are not normally prefixed with an underscore
   on this system, the asm identifier `syscall_error' intrudes on the
   C name space.  Make sure we use an innocuous name.  */
# define syscall_error   __syscall_error
# define mcount      _mcount

# define PSEUDO(name, syscall_name, args)     \
  .globl syscall_error;                       \
  ENTRY (name)                                \
    DO_CALL (syscall_name, args);

# define ret                                  \
  rtsd r15,8; nop;

# undef PSEUDO_END
# define PSEUDO_END(name)                     \
  END (name)

# undef JUMPTARGET
# ifdef PIC
#  define JUMPTARGET(name)   name##@PLTPC
# else
#  define JUMPTARGET(name)   name
# endif

/* Local label name for asm code.  */
# ifndef L
#  define L(name) $L##name
# endif

# endif  /* __ASSEMBLER__  */
