// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <wasi/api.h>
#include <errno.h>
#include <fcntl.h>

int posix_fallocate(int fd, off_t offset, off_t len) {
  if (offset < 0 || len < 0)
    return EINVAL;
  return __wasi_fd_allocate(fd, offset, len);
}
