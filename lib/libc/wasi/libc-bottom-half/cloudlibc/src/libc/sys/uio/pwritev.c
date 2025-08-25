// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <sys/types.h>
#include <sys/uio.h>

#include <wasi/api.h>
#include <errno.h>

ssize_t pwritev(int fildes, const struct iovec *iov, int iovcnt, off_t offset) {
  if (iovcnt < 0 || offset < 0) {
    errno = EINVAL;
    return -1;
  }
  size_t bytes_written;
  __wasi_errno_t error = __wasi_fd_pwrite(
      fildes, (const __wasi_ciovec_t *)iov, iovcnt, offset, &bytes_written);
  if (error != 0) {
    errno = error;
    return -1;
  }
  return bytes_written;
}
