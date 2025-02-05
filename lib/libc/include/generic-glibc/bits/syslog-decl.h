/* Checking routines for syslog functions. Declaration only.
   Copyright (C) 2023-2024 Free Software Foundation, Inc.
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

#ifndef _BITS_SYSLOG_DECL_H
#define _BITS_SYSLOG_DECL_H 1

#ifndef _SYS_SYSLOG_H
# error "Never include <bits/syslog-decl.h> directly; use <sys/syslog.h> instead."
#endif

extern void __syslog_chk (int __pri, int __flag, const char *__fmt, ...)
     __attribute__ ((__format__ (__printf__, 3, 4)));

#ifdef __USE_MISC
extern void __vsyslog_chk (int __pri, int __flag, const char *__fmt,
			   __gnuc_va_list __ap)
     __attribute__ ((__format__ (__printf__, 3, 0)));
#endif

#endif