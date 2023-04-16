/* Generic implementation of the semaphore struct semid64_ds.
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

#ifndef _SYS_SEM_H
# error "Never include <bits/types/struct_semid_ds.h> directly; use <sys/sem.h> instead."
#endif

#if __TIMESIZE == 64
# define __semid64_ds semid_ds
#else
struct __semid64_ds
{
# include <bits/types/struct_semid64_ds_helper.h>
};
#endif