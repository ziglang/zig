/* Extra sys/procfs.h definitions.  S/390 version.
   Copyright (C) 2000-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_PROCFS_H
# error "Never include <bits/procfs-extra.h> directly; use <sys/procfs.h> instead."
#endif

#if __WORDSIZE == 64

/* Provide 32-bit variants so that BFD can read 32-bit
   core files.  */
#define ELF_NGREG32	36
typedef unsigned int elf_greg_t32;
typedef elf_greg_t32
  elf_gregset_t32[ELF_NGREG32] __attribute__ ((__aligned__ (8)));
typedef elf_fpregset_t elf_fpregset_t32;

struct elf_prstatus32
  {
    struct elf_siginfo pr_info;		/* Info associated with signal.  */
    short int pr_cursig;		/* Current signal.  */
    unsigned int pr_sigpend;	/* Set of pending signals.  */
    unsigned int pr_sighold;	/* Set of held signals.  */
    __pid_t pr_pid;
    __pid_t pr_ppid;
    __pid_t pr_pgrp;
    __pid_t pr_sid;
    struct
      {
	int tv_sec, tv_usec;
      } pr_utime,			/* User time.  */
        pr_stime,			/* System time.  */
        pr_cutime,			/* Cumulative user time.  */
        pr_cstime;			/* Cumulative system time.  */
    elf_gregset_t32 pr_reg;		/* GP registers.  */
    int pr_fpvalid;			/* True if math copro being used.  */
  };

struct elf_prpsinfo32
  {
    char pr_state;			/* Numeric process state.  */
    char pr_sname;			/* Char for pr_state.  */
    char pr_zomb;			/* Zombie.  */
    char pr_nice;			/* Nice val.  */
    unsigned int pr_flag;		/* Flags.  */
    unsigned short int pr_uid;
    unsigned short int pr_gid;
    int pr_pid, pr_ppid, pr_pgrp, pr_sid;
    /* Lots missing */
    char pr_fname[16];			/* Filename of executable.  */
    char pr_psargs[ELF_PRARGSZ];	/* Initial part of arg list.  */
  };

typedef elf_gregset_t32 prgregset32_t;
typedef elf_fpregset_t32 prfpregset32_t;

typedef struct elf_prstatus32 prstatus32_t;
typedef struct elf_prpsinfo32 prpsinfo32_t;

#endif