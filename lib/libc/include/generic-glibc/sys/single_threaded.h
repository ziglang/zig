/* Support for single-thread optimizations.
   Copyright (C) 2020 Free Software Foundation, Inc.
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

#ifndef _SYS_SINGLE_THREADED_H
#define _SYS_SINGLE_THREADED_H

#include <features.h>

__BEGIN_DECLS

/* If this variable is non-zero, then the current thread is the only
   thread in the process image.  If it is zero, the process might be
   multi-threaded.  */
extern char __libc_single_threaded;

__END_DECLS

#endif /* _SYS_SINGLE_THREADED_H */