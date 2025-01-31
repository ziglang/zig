/* Checking routines for select functions. Declaration only.
   Copyright (C) 2023-2025 Free Software Foundation, Inc.
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

#ifndef _BITS_SELECT_DECL_H
#define _BITS_SELECT_DECL_H 1

#ifndef _SYS_SELECT_H
# error "Never include <bits/select-decl.h> directly; use <sys/select.h> instead."
#endif

/* Helper functions to issue warnings and errors when needed.  */
extern long int __fdelt_chk (long int __d);
extern long int __fdelt_warn (long int __d)
  __warnattr ("bit outside of fd_set selected");

#endif