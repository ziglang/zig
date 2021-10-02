/* Copyright (C) 2008-2021 Free Software Foundation, Inc.
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

#ifndef _SYS_USER_H
#define _SYS_USER_H	1

/* The whole purpose of this file is for GDB and GDB only.  Don't read
   too much into it.  Don't use it for anything other than GDB unless
   you know what you are doing.  */

struct user_m68kfp_struct {
	unsigned long fpregs[8*3];
	unsigned long fpcntl[3];
};

struct user_regs_struct {
	long d1, d2, d3, d4, d5, d6, d7;
	long a0, a1, a2, a3, a4, a5, a6;
	long d0;
	long usp;
	long orig_d0;
	short stkadj;
	short sr;
	long pc;
	short fmtvec;
	short __fill;
};

struct user {
	struct user_regs_struct regs;
	int u_fpvalid;
	struct user_m68kfp_struct m68kfp;
	unsigned long int u_tsize;
	unsigned long int u_dsize;
	unsigned long int u_ssize;
	unsigned long start_code;
	unsigned long start_stack;
	long int signal;
	int reserved;
	unsigned long u_ar0;
	struct user_m68kfp_struct *u_fpstate;
	unsigned long magic;
	char u_comm[32];
};

#define NBPG 4096
#define UPAGES 1
#define HOST_TEXT_START_ADDR u.start_code
#define HOST_STACK_END_ADDR (u.start_stack + u.u_ssize * NBPG)

#endif