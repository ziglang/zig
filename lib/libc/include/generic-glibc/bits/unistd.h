/* Checking macros for unistd functions.
   Copyright (C) 2005-2024 Free Software Foundation, Inc.
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

#ifndef _UNISTD_H
# error "Never include <bits/unistd.h> directly; use <unistd.h> instead."
#endif

# include <bits/unistd-decl.h>

__fortify_function __wur ssize_t
read (int __fd, void *__buf, size_t __nbytes)
{
  return __glibc_fortify (read, __nbytes, sizeof (char),
			  __glibc_objsize0 (__buf),
			  __fd, __buf, __nbytes);
}

#if defined __USE_UNIX98 || defined __USE_XOPEN2K8
# ifndef __USE_FILE_OFFSET64
__fortify_function __wur ssize_t
pread (int __fd, void *__buf, size_t __nbytes, __off_t __offset)
{
  return __glibc_fortify (pread, __nbytes, sizeof (char),
			  __glibc_objsize0 (__buf),
			  __fd, __buf, __nbytes, __offset);
}
# else
__fortify_function __wur ssize_t
pread (int __fd, void *__buf, size_t __nbytes, __off64_t __offset)
{
  return __glibc_fortify (pread64, __nbytes, sizeof (char),
			  __glibc_objsize0 (__buf),
			  __fd, __buf, __nbytes, __offset);
}
# endif

# ifdef __USE_LARGEFILE64
__fortify_function __wur ssize_t
pread64 (int __fd, void *__buf, size_t __nbytes, __off64_t __offset)
{
  return __glibc_fortify (pread64, __nbytes, sizeof (char),
			  __glibc_objsize0 (__buf),
			  __fd, __buf, __nbytes, __offset);
}
# endif
#endif

#if defined __USE_XOPEN_EXTENDED || defined __USE_XOPEN2K
__fortify_function __nonnull ((1, 2)) __wur ssize_t
__NTH (readlink (const char *__restrict __path, char *__restrict __buf,
		 size_t __len))
{
  return __glibc_fortify (readlink, __len, sizeof (char),
			  __glibc_objsize (__buf),
			  __path, __buf, __len);
}
#endif

#ifdef __USE_ATFILE
__fortify_function __nonnull ((2, 3)) __wur ssize_t
__NTH (readlinkat (int __fd, const char *__restrict __path,
		   char *__restrict __buf, size_t __len))
{
  return __glibc_fortify (readlinkat, __len, sizeof (char),
			  __glibc_objsize (__buf),
			  __fd, __path, __buf, __len);
}
#endif

__fortify_function __wur char *
__NTH (getcwd (char *__buf, size_t __size))
{
  return __glibc_fortify (getcwd, __size, sizeof (char),
			  __glibc_objsize (__buf),
			  __buf, __size);
}

#if defined __USE_MISC || defined __USE_XOPEN_EXTENDED
__fortify_function __nonnull ((1)) __attribute_deprecated__ __wur char *
__NTH (getwd (char *__buf))
{
  if (__glibc_objsize (__buf) != (size_t) -1)
    return __getwd_chk (__buf, __glibc_objsize (__buf));
  return __getwd_warn (__buf);
}
#endif

__fortify_function size_t
__NTH (confstr (int __name, char *__buf, size_t __len))
{
  return __glibc_fortify (confstr, __len, sizeof (char),
			  __glibc_objsize (__buf),
			  __name, __buf, __len);
}


__fortify_function int
__NTH (getgroups (int __size, __gid_t __list[]))
{
  return __glibc_fortify (getgroups, __size, sizeof (__gid_t),
			  __glibc_objsize (__list),
			  __size, __list);
}


__fortify_function int
__NTH (ttyname_r (int __fd, char *__buf, size_t __buflen))
{
  return __glibc_fortify (ttyname_r, __buflen, sizeof (char),
			  __glibc_objsize (__buf),
			  __fd, __buf, __buflen);
}


#ifdef __USE_POSIX199506
__fortify_function int
getlogin_r (char *__buf, size_t __buflen)
{
  return __glibc_fortify (getlogin_r, __buflen, sizeof (char),
			  __glibc_objsize (__buf),
			  __buf, __buflen);
}
#endif


#if defined __USE_MISC || defined __USE_UNIX98
__fortify_function int
__NTH (gethostname (char *__buf, size_t __buflen))
{
  return __glibc_fortify (gethostname, __buflen, sizeof (char),
			  __glibc_objsize (__buf),
			  __buf, __buflen);
}
#endif


#if defined __USE_MISC || (defined __USE_XOPEN && !defined __USE_UNIX98)
__fortify_function int
__NTH (getdomainname (char *__buf, size_t __buflen))
{
  return __glibc_fortify (getdomainname, __buflen, sizeof (char),
			  __glibc_objsize (__buf),
			  __buf, __buflen);
}
#endif