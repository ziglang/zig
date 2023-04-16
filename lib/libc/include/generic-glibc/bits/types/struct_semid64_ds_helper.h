/* Common definitions for struct semid_ds with 64-bit time.
   Copyright (C) 2020-2023 Free Software Foundation, Inc.
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

  /* Content of internal __semid64_ds.  */
  struct ipc_perm sem_perm;		/* operation permission struct */
  __time64_t sem_otime;			/* last semop() time */
  __time64_t sem_ctime;			/* last time changed by semctl() */
  __syscall_ulong_t sem_nsems;		/* number of semaphores in set */
  unsigned long int __glibc_reserved3;
  unsigned long int __glibc_reserved4;