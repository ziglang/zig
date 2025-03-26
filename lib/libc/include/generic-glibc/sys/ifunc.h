/* Definitions used by AArch64 indirect function resolvers.
   Copyright (C) 2019-2025 Free Software Foundation, Inc.
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

#ifndef _SYS_IFUNC_H
#define _SYS_IFUNC_H

/* A second argument is passed to the ifunc resolver.  */
#define _IFUNC_ARG_HWCAP	(1ULL << 62)

/* The prototype of a gnu indirect function resolver on AArch64 is

     ElfW(Addr) ifunc_resolver (uint64_t, const __ifunc_arg_t *);

   the first argument should have the _IFUNC_ARG_HWCAP bit set and
   the remaining bits should match the AT_HWCAP settings.  */

/* Second argument to an ifunc resolver.  */
struct __ifunc_arg_t
{
  unsigned long _size; /* Size of the struct, so it can grow.  */
  unsigned long _hwcap;
  unsigned long _hwcap2;
};

typedef struct __ifunc_arg_t __ifunc_arg_t;

#endif