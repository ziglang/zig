/* struct ipc_perm definition.  Linux/powerpc version.
   Copyright (C) 1995-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_IPC_H
# error "Never use <bits/ipc-perm.h> directly; include <sys/ipc.h> instead."
#endif

/* Data structure used to pass permission information to IPC operations.  */
struct ipc_perm
  {
    __key_t __key;		/* Key.  */
    __uid_t uid;		/* Owner's user ID.  */
    __gid_t gid;		/* Owner's group ID.  */
    __uid_t cuid;		/* Creator's user ID.  */
    __gid_t cgid;		/* Creator's group ID.  */
    __mode_t mode;		/* Read/write permission.  */
    __uint32_t __seq;		/* Sequence number.  */
    __uint32_t __pad1;
    __uint64_t __glibc_reserved1;
    __uint64_t __glibc_reserved2;
  };