/* x86 implementation of the semaphore struct semid_ds.
   Copyright (C) 1995-2024 Free Software Foundation, Inc.
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

#ifndef _SYS_SEM_H
# error "Never include <bits/types/struct_semid_ds.h> directly; use <sys/sem.h> instead."
#endif

/* Data structure describing a set of semaphores.  */
struct semid_ds
{
#ifdef __USE_TIME64_REDIRECTS
# include <bits/types/struct_semid64_ds_helper.h>
#else
  struct ipc_perm sem_perm;   /* operation permission struct */
  __time_t sem_otime;  /* last semop() time */
  __syscall_ulong_t __sem_otime_high;
  __time_t sem_ctime;  /* last time changed by semctl() */
  __syscall_ulong_t __sem_ctime_high;
  __syscall_ulong_t sem_nsems;    /* number of semaphores in set */
  __syscall_ulong_t __glibc_reserved3;
  __syscall_ulong_t __glibc_reserved4;
#endif
};