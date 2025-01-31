/* Checking routines for unistd functions. Declaration only.
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

#ifndef _BITS_UNISTD_DECL_H
#define _BITS_UNISTD_DECL_H 1

#ifndef _UNISTD_H
# error "Never include <bits/unistd-decl.h> directly; use <unistd.h> instead."
#endif

extern ssize_t __read_chk (int __fd, void *__buf, size_t __nbytes,
			   size_t __buflen)
     __wur __attr_access ((__write_only__, 2, 3));
extern ssize_t __REDIRECT_FORTIFY (__read_alias, (int __fd, void *__buf,
						  size_t __nbytes), read)
     __wur __attr_access ((__write_only__, 2, 3));
extern ssize_t __REDIRECT (__read_chk_warn,
			   (int __fd, void *__buf, size_t __nbytes,
			    size_t __buflen), __read_chk)
     __wur __warnattr ("read called with bigger length than size of "
		       "the destination buffer");

#if defined __USE_UNIX98 || defined __USE_XOPEN2K8
extern ssize_t __pread_chk (int __fd, void *__buf, size_t __nbytes,
			    __off_t __offset, size_t __bufsize)
     __wur __attr_access ((__write_only__, 2, 3));
extern ssize_t __pread64_chk (int __fd, void *__buf, size_t __nbytes,
			      __off64_t __offset, size_t __bufsize)
     __wur __attr_access ((__write_only__, 2, 3));
extern ssize_t __REDIRECT (__pread_alias,
			   (int __fd, void *__buf, size_t __nbytes,
			    __off_t __offset), pread)
     __wur __attr_access ((__write_only__, 2, 3));
extern ssize_t __REDIRECT (__pread64_alias,
			   (int __fd, void *__buf, size_t __nbytes,
			    __off64_t __offset), pread64)
     __wur __attr_access ((__write_only__, 2, 3));
extern ssize_t __REDIRECT (__pread_chk_warn,
			   (int __fd, void *__buf, size_t __nbytes,
			    __off_t __offset, size_t __bufsize), __pread_chk)
     __wur __warnattr ("pread called with bigger length than size of "
		       "the destination buffer");
extern ssize_t __REDIRECT (__pread64_chk_warn,
			   (int __fd, void *__buf, size_t __nbytes,
			    __off64_t __offset, size_t __bufsize),
			    __pread64_chk)
     __wur __warnattr ("pread64 called with bigger length than size of "
		       "the destination buffer");
#endif

#if defined __USE_XOPEN_EXTENDED || defined __USE_XOPEN2K
extern ssize_t __readlink_chk (const char *__restrict __path,
			       char *__restrict __buf, size_t __len,
			       size_t __buflen)
     __THROW __nonnull ((1, 2)) __wur __attr_access ((__write_only__, 2, 3));
extern ssize_t __REDIRECT_NTH (__readlink_alias,
			       (const char *__restrict __path,
				char *__restrict __buf, size_t __len), readlink)
     __nonnull ((1, 2)) __wur __attr_access ((__write_only__, 2, 3));
extern ssize_t __REDIRECT_NTH (__readlink_chk_warn,
			       (const char *__restrict __path,
				char *__restrict __buf, size_t __len,
				size_t __buflen), __readlink_chk)
     __nonnull ((1, 2)) __wur __warnattr ("readlink called with bigger length "
					  "than size of destination buffer");
#endif

#ifdef __USE_ATFILE
extern ssize_t __readlinkat_chk (int __fd, const char *__restrict __path,
				 char *__restrict __buf, size_t __len,
				 size_t __buflen)
     __THROW __nonnull ((2, 3)) __wur __attr_access ((__write_only__, 3, 4));
extern ssize_t __REDIRECT_NTH (__readlinkat_alias,
			       (int __fd, const char *__restrict __path,
				char *__restrict __buf, size_t __len),
			       readlinkat)
     __nonnull ((2, 3)) __wur __attr_access ((__write_only__, 3, 4));
extern ssize_t __REDIRECT_NTH (__readlinkat_chk_warn,
			       (int __fd, const char *__restrict __path,
				char *__restrict __buf, size_t __len,
				size_t __buflen), __readlinkat_chk)
     __nonnull ((2, 3)) __wur __warnattr ("readlinkat called with bigger "
					  "length than size of destination "
					  "buffer");
#endif

extern char *__getcwd_chk (char *__buf, size_t __size, size_t __buflen)
     __THROW __wur;
extern char *__REDIRECT_NTH (__getcwd_alias,
			     (char *__buf, size_t __size), getcwd) __wur;
extern char *__REDIRECT_NTH (__getcwd_chk_warn,
			     (char *__buf, size_t __size, size_t __buflen),
			     __getcwd_chk)
     __wur __warnattr ("getcwd caller with bigger length than size of "
		       "destination buffer");

#if defined __USE_MISC || defined __USE_XOPEN_EXTENDED
extern char *__getwd_chk (char *__buf, size_t buflen)
     __THROW __nonnull ((1)) __wur __attr_access ((__write_only__, 1, 2));
extern char *__REDIRECT_NTH (__getwd_warn, (char *__buf), getwd)
     __nonnull ((1)) __wur __warnattr ("please use getcwd instead, as getwd "
				       "doesn't specify buffer size");
#endif

extern size_t __confstr_chk (int __name, char *__buf, size_t __len,
			     size_t __buflen) __THROW
     __attr_access ((__write_only__, 2, 3));
extern size_t __REDIRECT_NTH (__confstr_alias, (int __name, char *__buf,
						size_t __len), confstr)
     __attr_access ((__write_only__, 2, 3));
extern size_t __REDIRECT_NTH (__confstr_chk_warn,
			      (int __name, char *__buf, size_t __len,
			       size_t __buflen), __confstr_chk)
     __warnattr ("confstr called with bigger length than size of destination "
		 "buffer");


extern int __getgroups_chk (int __size, __gid_t __list[], size_t __listlen)
     __THROW __wur __attr_access ((__write_only__, 2, 1));
extern int __REDIRECT_NTH (__getgroups_alias, (int __size, __gid_t __list[]),
			   getgroups) __wur __attr_access ((__write_only__, 2, 1));
extern int __REDIRECT_NTH (__getgroups_chk_warn,
			   (int __size, __gid_t __list[], size_t __listlen),
			   __getgroups_chk)
     __wur __warnattr ("getgroups called with bigger group count than what "
		       "can fit into destination buffer");


extern int __ttyname_r_chk (int __fd, char *__buf, size_t __buflen,
			    size_t __nreal) __THROW __nonnull ((2))
     __attr_access ((__write_only__, 2, 3));
extern int __REDIRECT_NTH (__ttyname_r_alias, (int __fd, char *__buf,
					       size_t __buflen), ttyname_r)
     __nonnull ((2));
extern int __REDIRECT_NTH (__ttyname_r_chk_warn,
			   (int __fd, char *__buf, size_t __buflen,
			    size_t __nreal), __ttyname_r_chk)
     __nonnull ((2)) __warnattr ("ttyname_r called with bigger buflen than "
				 "size of destination buffer");


#ifdef __USE_POSIX199506
extern int __getlogin_r_chk (char *__buf, size_t __buflen, size_t __nreal)
     __nonnull ((1)) __attr_access ((__write_only__, 1, 2));
extern int __REDIRECT_FORTIFY (__getlogin_r_alias, (char *__buf, size_t __buflen),
		       getlogin_r) __nonnull ((1));
extern int __REDIRECT (__getlogin_r_chk_warn,
		       (char *__buf, size_t __buflen, size_t __nreal),
		       __getlogin_r_chk)
     __nonnull ((1)) __warnattr ("getlogin_r called with bigger buflen than "
				 "size of destination buffer");
#endif


#if defined __USE_MISC || defined __USE_UNIX98
extern int __gethostname_chk (char *__buf, size_t __buflen, size_t __nreal)
     __THROW __nonnull ((1)) __attr_access ((__write_only__, 1, 2));
extern int __REDIRECT_NTH (__gethostname_alias, (char *__buf, size_t __buflen),
			   gethostname)
     __nonnull ((1)) __attr_access ((__write_only__, 1, 2));
extern int __REDIRECT_NTH (__gethostname_chk_warn,
			   (char *__buf, size_t __buflen, size_t __nreal),
			   __gethostname_chk)
     __nonnull ((1)) __warnattr ("gethostname called with bigger buflen than "
				 "size of destination buffer");
#endif


#if defined __USE_MISC || (defined __USE_XOPEN && !defined __USE_UNIX98)
extern int __getdomainname_chk (char *__buf, size_t __buflen, size_t __nreal)
     __THROW __nonnull ((1)) __wur __attr_access ((__write_only__, 1, 2));
extern int __REDIRECT_FORTIFY_NTH (__getdomainname_alias, (char *__buf,
						   size_t __buflen),
			   getdomainname) __nonnull ((1))
     __wur __attr_access ((__write_only__, 1, 2));
extern int __REDIRECT_NTH (__getdomainname_chk_warn,
			   (char *__buf, size_t __buflen, size_t __nreal),
			   __getdomainname_chk)
     __nonnull ((1)) __wur __warnattr ("getdomainname called with bigger "
				       "buflen than size of destination "
				       "buffer");
#endif
#endif /* bits/unistd-decl.h.  */