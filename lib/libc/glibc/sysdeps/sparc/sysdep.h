/* Copyright (C) 2011-2021 Free Software Foundation, Inc.
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

#define _SYSDEPS_SYSDEP_H 1
#include <bits/hwcap.h>

#ifdef	__ASSEMBLER__

#define SPARC_PIC_THUNK(reg)						\
	.ifndef __sparc_get_pc_thunk.reg;				\
	.section .text.__sparc_get_pc_thunk.reg,"axG",@progbits,__sparc_get_pc_thunk.reg,comdat; \
	.align	 32;							\
	.weak	 __sparc_get_pc_thunk.reg;				\
	.hidden	 __sparc_get_pc_thunk.reg;				\
	.type	 __sparc_get_pc_thunk.reg, #function;			\
__sparc_get_pc_thunk.reg:		   				\
	jmp	%o7 + 8;						\
	 add	%o7, %reg, %##reg;					\
	.previous;							\
	.endif;

/* The "-4" and "+4" offsets against _GLOBAL_OFFSET_TABLE_ are
   critical since they represent the offset from the thunk call to the
   instruction containing the _GLOBAL_OFFSET_TABLE_ reference.
   Therefore these instructions cannot be moved around without
   appropriate adjustments to those offsets.

   Furthermore, these expressions are special in another regard.  When
   the assembler sees a reference to _GLOBAL_OFFSET_TABLE_ inside of
   a %hi() or %lo(), it emits a PC-relative relocation.  This causes
   R_SPARC_HI22 to turn into R_SPARC_PC22, and R_SPARC_LO10 to turn into
   R_SPARC_PC10, respectively.

   Even when v9 we use a call sequence instead of using "rd %pc" because
   RDPC is extremely expensive and incurs a full pipeline flush.  */

#define SPARC_PIC_THUNK_CALL(reg)					\
	sethi	%hi(_GLOBAL_OFFSET_TABLE_-4), %##reg;			\
	call	__sparc_get_pc_thunk.reg;				\
	 or	%##reg, %lo(_GLOBAL_OFFSET_TABLE_+4), %##reg;

#define SETUP_PIC_REG(reg)						\
	SPARC_PIC_THUNK(reg)						\
	SPARC_PIC_THUNK_CALL(reg)

#define SETUP_PIC_REG_LEAF(reg, tmp)					\
	SPARC_PIC_THUNK(reg)						\
	mov	%o7, %##tmp;		      				\
	SPARC_PIC_THUNK_CALL(reg);					\
	mov	%##tmp, %o7;

#undef ENTRY
#define ENTRY(name)			\
	.align	4;			\
	.global	C_SYMBOL_NAME(name);	\
	.type	name, @function;	\
C_LABEL(name)				\
	cfi_startproc;

#undef END
#define END(name)			\
	cfi_endproc;			\
	.size name, . - name

#undef LOC
#define LOC(name)  .L##name

#endif	/* __ASSEMBLER__ */
