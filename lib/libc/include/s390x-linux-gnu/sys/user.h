/* Copyright (C) 2000-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_USER_H
#define _SYS_USER_H	1

/* The whole purpose of this file is for GDB and GDB only.  Don't read
   too much into it.  Don't use it for anything other than GDB unless
   you know what you are doing.  */

struct _user_psw_struct
{
  unsigned long mask;
  unsigned long addr;
};

struct _user_fpregs_struct
{
  unsigned int fpc;
  double fprs[16];
};

struct _user_per_struct
{
  unsigned long control_regs[3];
  unsigned single_step       : 1;
  unsigned instruction_fetch : 1;
  unsigned                   : 30;
  unsigned long starting_addr;
  unsigned long ending_addr;
  unsigned short perc_atmid;
  unsigned long address;
  unsigned char access_id;
};

struct _user_regs_struct
{
  struct _user_psw_struct psw;		/* Program status word.  */
  unsigned long gprs[16];		/* General purpose registers.  */
  unsigned int  acrs[16];		/* Access registers.  */
  unsigned long orig_gpr2;		/* Original gpr2.  */
  struct _user_fpregs_struct fp_regs;	/* Floating point registers.  */
  struct _user_per_struct per_info;	/* Hardware tracing registers.  */
  unsigned long ieee_instruction_pointer;	/* Always 0.  */
};

struct user {
  struct _user_regs_struct regs;	/* User registers.  */
  unsigned long int u_tsize;		/* Text segment size (pages).  */
  unsigned long int u_dsize;		/* Data segment size (pages).  */
  unsigned long int u_ssize;		/* Stack segment size (pages).  */
  unsigned long start_code;		/* Starting address of text.  */
  unsigned long start_stack;		/* Starting address of stack area.  */
  long int signal;			/* Signal causing the core dump.  */
  struct _user_regs_struct *u_ar0;	/* Help gdb find registers.  */
  unsigned long magic;			/* Identifies a core file.  */
  char u_comm[32];			/* User command naem.  */
};

#define PAGE_SHIFT		12
#define PAGE_SIZE		(1UL << PAGE_SHIFT)
#define PAGE_MASK		(~(PAGE_SIZE-1))
#define NBPG			PAGE_SIZE
#define UPAGES			1
#define HOST_TEXT_START_ADDR	(u.start_code)
#define HOST_STACK_END_ADDR	(u.start_stack + u.u_ssize * NBPG)

#endif	/* _SYS_USER_H */