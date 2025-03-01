/* Copyright (C) 1995-2025 Free Software Foundation, Inc.
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

#ifndef _SYS_SYSMIPS_H
#define _SYS_SYSMIPS_H 1

#include <features.h>

/*
 * Commands for the sysmips(2) call
 *
 * sysmips(2) is deprecated - though some existing software uses it.
 * We only support the following commands.  Sysmips exists for compatibility
 * purposes only so new software should avoid it.
 */
#define SETNAME                   1	/* set hostname                  */
#define FLUSH_CACHE		   3	/* writeback and invalidate caches */
#define MIPS_FIXADE               7	/* control address error fixing  */
#define MIPS_RDNVRAM              10	/* read NVRAM			 */
#define MIPS_ATOMIC_SET		2001	/* atomically set variable       */

__BEGIN_DECLS

extern int sysmips (const int __cmd, ...) __THROW;

__END_DECLS

#endif /* sys/sysmips.h */