/* bits/typesizes.h -- underlying types for *_t.  Hurd version.
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

#ifndef _BITS_TYPES_H
# error "Never include <bits/typesizes.h> directly; use <sys/types.h> instead."
#endif

#ifndef	_BITS_TYPESIZES_H
#define	_BITS_TYPESIZES_H	1

/* See <bits/types.h> for the meaning of these macros.  This file exists so
   that <bits/types.h> need not vary across different GNU platforms.  */

#define __DEV_T_TYPE		__U32_TYPE
#define __UID_T_TYPE		__U32_TYPE
#define __GID_T_TYPE		__U32_TYPE
#define __INO_T_TYPE		__ULONGWORD_TYPE
#define __INO64_T_TYPE		__UQUAD_TYPE
#define __MODE_T_TYPE		__U32_TYPE
#define __NLINK_T_TYPE		__UWORD_TYPE
#define __OFF_T_TYPE		__SLONGWORD_TYPE
#define __OFF64_T_TYPE		__SQUAD_TYPE
#define __PID_T_TYPE		__S32_TYPE
#define __RLIM_T_TYPE		__ULONGWORD_TYPE
#define __RLIM64_T_TYPE		__UQUAD_TYPE
#define	__BLKCNT_T_TYPE		__SLONGWORD_TYPE
#define	__BLKCNT64_T_TYPE	__SQUAD_TYPE
#define	__FSBLKCNT_T_TYPE	__ULONGWORD_TYPE
#define	__FSBLKCNT64_T_TYPE	__UQUAD_TYPE
#define	__FSFILCNT_T_TYPE	__ULONGWORD_TYPE
#define	__FSFILCNT64_T_TYPE	__UQUAD_TYPE
#define	__FSWORD_T_TYPE		__SWORD_TYPE
#define	__ID_T_TYPE		__U32_TYPE
#define __CLOCK_T_TYPE		__SLONGWORD_TYPE
#define __TIME_T_TYPE		__SLONGWORD_TYPE
#define __USECONDS_T_TYPE	__U32_TYPE
#define __SUSECONDS_T_TYPE	__SLONGWORD_TYPE
#define __DADDR_T_TYPE		__S32_TYPE
#define __KEY_T_TYPE		__S32_TYPE
#define __CLOCKID_T_TYPE	__S32_TYPE
#define __TIMER_T_TYPE		__S32_TYPE
#define __BLKSIZE_T_TYPE	__SLONGWORD_TYPE
#define __FSID_T_TYPE		__UQUAD_TYPE
#define __SSIZE_T_TYPE		__SWORD_TYPE
#define __SYSCALL_SLONG_TYPE	__SLONGWORD_TYPE
#define __SYSCALL_ULONG_TYPE	__ULONGWORD_TYPE
#define __CPU_MASK_TYPE 	__ULONGWORD_TYPE

/* Number of descriptors that can fit in an `fd_set'.  */
#define	__FD_SETSIZE		256

/* Tell the libc code that fsblkcnt_t, fsblkcnt64_t, fsfilcnt_t and
   fsfilcnt64_t are not the same type for all ABI purposes.  */
# define __STATFS_MATCHES_STATFS64  0


#endif /* bits/typesizes.h */
