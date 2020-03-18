/* Copyright (C) 1992-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Brendan Kehoe (brendan@zen.org).

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

#include <sgidefs.h>
#include <sysdeps/unix/sysdep.h>

#ifndef __mips_isa_rev
# define __mips_isa_rev 0
#endif

#ifdef __ASSEMBLER__

#include <regdef.h>

#define ENTRY(name) \
  .globl name;								      \
  .align 2;								      \
  .ent name,0;								      \
  name##:								      \
  cfi_startproc;

#undef END
#define	END(function)                                   \
		cfi_endproc;				\
		.end	function;		        \
		.size	function,.-function

#define ret	j ra ; nop

#undef PSEUDO_END
#define PSEUDO_END(sym) cfi_endproc; .end sym; .size sym,.-sym

#define PSEUDO_NOERRNO(name, syscall_name, args)	\
  .align 2;						\
  ENTRY(name)						\
  .set nomips16;					\
  .set noreorder;					\
  li v0, SYS_ify(syscall_name);				\
  syscall

#undef PSEUDO_END_NOERRNO
#define PSEUDO_END_NOERRNO(sym) cfi_endproc; .end sym; .size sym,.-sym

#define ret_NOERRNO ret

#define PSEUDO_ERRVAL(name, syscall_name, args)	\
  .align 2;						\
  ENTRY(name)						\
  .set nomips16;					\
  .set noreorder;					\
  li v0, SYS_ify(syscall_name);				\
  syscall

#undef PSEUDO_END_ERRVAL
#define PSEUDO_END_ERRVAL(sym) cfi_endproc; .end sym; .size sym,.-sym

#define ret_ERRVAL ret

#define r0	v0
#define r1	v1
/* The mips move insn is d,s.  */
#define MOVE(x,y)	move y , x

#if _MIPS_SIM == _ABIO32
# define L(label) $L ## label
#else
# define L(label) .L ## label
#endif

#endif
