/* Get file status.  Linux version.
   Copyright (C) 2020-2025 Free Software Foundation, Inc.
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

#define __fstat __redirect___fstat
#define fstat   __redirect_fstat
#include <sys/stat.h>
#undef __fstat
#undef fstat
#include <fcntl.h>
#include <internal-stat.h>
#include <errno.h>

int
__fstat64_time64 (int fd, struct __stat64_t64 *buf)
{
#if !FSTATAT_USE_STATX
# if XSTAT_IS_XSTAT64
  /* The __NR_stat macro is defined for all ABIs that also define
     XSTAT_IS_STAT64, so to correctly identify alpha and sparc check
     __NR_newfstatat (similar to what fstatat64 does).  */
#  ifdef __NR_newfstatat
  /* 64-bit kABI, e.g. aarch64, ia64, powerpc64*, s390x, riscv64, and
     x86_64.  */
  return INLINE_SYSCALL_CALL (fstat, fd, buf);
#  elif defined __NR_fstat64
#   if STAT64_IS_KERNEL_STAT64
  /* 64-bit kABI outlier, e.g. alpha  */
  return INLINE_SYSCALL_CALL (fstat64, fd, buf);
#   else
  /* 64-bit kABI outlier, e.g. sparc64.  */
  struct kernel_stat64 kst64;
  int r = INLINE_SYSCALL_CALL (fstat64, fd, &kst64);
  if (r == 0)
    __cp_stat64_kstat64 (buf, &kst64);
  return r;
#   endif /* STAT64_IS_KERNEL_STAT64 */
#  endif
# else /* XSTAT_IS_XSTAT64 */
  /* 64-bit kabi outlier, e.g. mips64 and mips64-n32.  */
  struct kernel_stat kst;
  int r = INLINE_SYSCALL_CALL (fstat, fd, &kst);
  if (r == 0)
    __cp_kstat_stat64_t64 (&kst, buf);
  return r;
# endif
#else /* !FSTATAT_USE_STATX  */
  /* All kABIs with non-LFS support and with old 32-bit time_t support
     e.g. arm, csky, i386, hppa, m68k, microblaze, sh, powerpc32,
     and sparc32.  */
  if (fd < 0)
    {
      __set_errno (EBADF);
      return -1;
    }
  return __fstatat64_time64 (fd, "", buf, AT_EMPTY_PATH);
#endif
}
#if __TIMESIZE != 64
hidden_def (__fstat64_time64)

int
__fstat64 (int fd, struct stat64 *buf)
{
  if (fd < 0)
    {
      __set_errno (EBADF);
      return -1;
    }

  struct __stat64_t64 st_t64;
  return __fstat64_time64 (fd, &st_t64)
	 ?: __cp_stat64_t64_stat64 (&st_t64, buf);
}
#endif

#undef __fstat
#undef fstat

hidden_def (__fstat64)
weak_alias (__fstat64, fstat64)

#if XSTAT_IS_XSTAT64
strong_alias (__fstat64, __fstat)
weak_alias (__fstat64, fstat)
#endif
