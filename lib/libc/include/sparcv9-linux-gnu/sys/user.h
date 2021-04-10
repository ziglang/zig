/* Copyright (C) 2003-2021 Free Software Foundation, Inc.
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

#include <stddef.h>

struct sunos_regs
{
  unsigned int psr, pc, npc, y;
  unsigned int regs[15];
};

struct sunos_fpqueue
{
  unsigned int *addr;
  unsigned int inst;
};

struct sunos_fp
{
  union
    {
      unsigned int regs[32];
      double reg_dbls[16];
    } fregs;
  unsigned int fsr;
  unsigned int flags;
  unsigned int extra;
  unsigned int fpq_count;
  struct sunos_fpqueue fpq[16];
};

struct sunos_fpu
{
  struct sunos_fp fpstatus;
};

/* The SunOS core file header layout. */
struct user {
  unsigned int magic;
  unsigned int len;
  struct sunos_regs regs;
  struct
    {
      unsigned char a_dynamic :1;
      unsigned char a_toolversion :7;
      unsigned char a_machtype;
      unsigned short a_info;
      unsigned int a_text;
      unsigned int a_data;
      unsigned int a_bss;
      unsigned int a_syms;
      unsigned int a_entry;
      unsigned int a_trsize;
      unsigned int a_drsize;
    } uexec;
  int           signal;
  size_t        u_tsize;
  size_t        u_dsize;
  size_t        u_ssize;
  char          u_comm[17];
  struct sunos_fpu fpu;
  unsigned int  sigcode;
};

#define NBPG			0x2000
#define UPAGES			1
#define SUNOS_CORE_MAGIC	0x080456

#endif