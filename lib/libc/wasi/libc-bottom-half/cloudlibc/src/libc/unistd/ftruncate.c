// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <wasi/api.h>
#include <errno.h>
#include <unistd.h>

int ftruncate(int fildes, off_t length) {
  if (length < 0) {
    errno = EINVAL;
    return -1;
  }
  __wasi_filesize_t st_size = length;
  __wasi_errno_t error =
      __wasi_fd_filestat_set_size(fildes, st_size);
  if (error != 0) {
    errno = error;
    return -1;
  }
  return 0;
}
