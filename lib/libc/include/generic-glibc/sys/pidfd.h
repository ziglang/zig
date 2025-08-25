/* Wrapper for file descriptors that refers to a process functions.
   Copyright (C) 2022-2025 Free Software Foundation, Inc.
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

#ifndef _PIDFD_H

#include <fcntl.h>
#include <bits/types/siginfo_t.h>
#include <sys/ioctl.h>

// zig patch: check target glibc version
#if (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 36) || __GLIBC__ > 2

#define PIDFD_NONBLOCK O_NONBLOCK
#define PIDFD_THREAD O_EXCL

#define PIDFD_SIGNAL_THREAD (1UL << 0)
#define PIDFD_SIGNAL_THREAD_GROUP (1UL << 1)
#define PIDFD_SIGNAL_PROCESS_GROUP (1UL << 2)

#define PIDFS_IOCTL_MAGIC 0xFF

#define PIDFD_GET_CGROUP_NAMESPACE            _IO(PIDFS_IOCTL_MAGIC, 1)
#define PIDFD_GET_IPC_NAMESPACE               _IO(PIDFS_IOCTL_MAGIC, 2)
#define PIDFD_GET_MNT_NAMESPACE               _IO(PIDFS_IOCTL_MAGIC, 3)
#define PIDFD_GET_NET_NAMESPACE               _IO(PIDFS_IOCTL_MAGIC, 4)
#define PIDFD_GET_PID_NAMESPACE               _IO(PIDFS_IOCTL_MAGIC, 5)
#define PIDFD_GET_PID_FOR_CHILDREN_NAMESPACE  _IO(PIDFS_IOCTL_MAGIC, 6)
#define PIDFD_GET_TIME_NAMESPACE              _IO(PIDFS_IOCTL_MAGIC, 7)
#define PIDFD_GET_TIME_FOR_CHILDREN_NAMESPACE _IO(PIDFS_IOCTL_MAGIC, 8)
#define PIDFD_GET_USER_NAMESPACE              _IO(PIDFS_IOCTL_MAGIC, 9)
#define PIDFD_GET_UTS_NAMESPACE               _IO(PIDFS_IOCTL_MAGIC, 10)

/* Returns a file descriptor that refers to the process PID.  The
   close-on-exec is set on the file descriptor.  */
extern int pidfd_open (__pid_t __pid, unsigned int __flags) __THROW;

/* Duplicates an existing file descriptor TARGETFD in the process referred
   by the PIDFD file descriptor PIDFD.

   The FLAGS argument is reserved for future use, it must be specified
   as 0.  */
extern int pidfd_getfd (int __pidfd, int __targetfd,
			unsigned int __flags) __THROW;

/* Sends the signal SIG to the target process referred by the PIDFD.  If
   INFO points to a siginfo_t buffer, it will be populated.  */
extern int pidfd_send_signal (int __pidfd, int __sig, siginfo_t *__info,
			      unsigned int __flags) __THROW;

#endif /* (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 36) || __GLIBC__ > 2 */

// zig patch: check target glibc version
#if (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 39) || __GLIBC__ > 2

/* Query the process ID (PID) from process descriptor FD.  Return the PID
   or -1 in case of an error.  */
extern pid_t pidfd_getpid (int __fd) __THROW;

#endif /* (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 36) || __GLIBC__ > 2 */

#endif /* _PIDFD_H  */
