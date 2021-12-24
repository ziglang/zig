/* Copyright (C) 1992-2021 Free Software Foundation, Inc.
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

/* Alan Modra <amodra@bigpond.net.au> rewrote the INLINE_SYSCALL macro */

#ifndef _LINUX_POWERPC64_SYSDEP_H
#define _LINUX_POWERPC64_SYSDEP_H 1

#include <sysdeps/unix/sysv/linux/powerpc/sysdep.h>

/* In the PowerPC64 ABI, the unadorned F_GETLK* opcodes should be used
   even by largefile64 code.  */
#define FCNTL_ADJUST_CMD(__cmd)				\
  ({ int cmd_ = (__cmd);				\
     if (cmd_ >= F_GETLK64 && cmd_ <= F_SETLKW64)	\
       cmd_ -= F_GETLK64 - F_GETLK;			\
     cmd_; })


#endif /* linux/powerpc/powerpc64/sysdep.h */
