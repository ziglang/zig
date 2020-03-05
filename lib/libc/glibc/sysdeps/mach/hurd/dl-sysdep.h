/* System-specific settings for dynamic linker code.  Hurd version.
   Copyright (C) 2002-2020 Free Software Foundation, Inc.
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

/* The private errno doesn't make sense on the Hurd.  errno is always the
   thread-local slot shared with libc, and it matters to share the cell
   with libc because after startup we use libc functions that set errno
   (open, mmap, etc).  */

#define RTLD_PRIVATE_ERRNO 0

#ifdef SHARED
/* _dl_argv and __libc_stack_end cannot be attribute_relro, because the stack-switching
   libc initializer for using cthreads might write into it.  */
# define DL_ARGV_NOT_RELRO 1
# define LIBC_STACK_END_NOT_RELRO 1
#endif
