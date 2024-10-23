/* Error constants.  Linux/Sparc specific version.
   Copyright (C) 1996-2024 Free Software Foundation, Inc.
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

#ifndef _BITS_ERRNO_H
#define _BITS_ERRNO_H 1

#if !defined _ERRNO_H
# error "Never include <bits/errno.h> directly; use <errno.h> instead."
#endif

# include <linux/errno.h>

/* Older Linux headers do not define these constants.  */
# ifndef ENOTSUP
#  define ENOTSUP		EOPNOTSUPP
# endif

# ifndef ECANCELED
#  define ECANCELED		127
# endif

# ifndef EOWNERDEAD
#  define EOWNERDEAD		132
# endif

# ifndef ENOTRECOVERABLE
#  define ENOTRECOVERABLE	133
# endif

# ifndef ERFKILL
#  define ERFKILL		134
# endif

# ifndef EHWPOISON
#  define EHWPOISON		135
# endif

#endif /* bits/errno.h.  */