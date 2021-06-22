/* C-SKY cache flushing interface.
   Copyright (C) 2018-2021 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_CACHECTL_H
#define _SYS_CACHECTL_H 1

#include <features.h>

/* Get the kernel definition for the op bits.  */
#include <asm/cachectl.h>

__BEGIN_DECLS

#ifdef __USE_MISC
extern int cacheflush (void *__addr, const int __nbytes,
		       const int __op) __THROW;
#endif

__END_DECLS

#endif /* sys/cachectl.h */