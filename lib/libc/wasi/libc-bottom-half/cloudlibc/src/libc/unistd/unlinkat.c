// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <wasi/api.h>
#include <wasi/libc.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int unlinkat(int fd, const char *path, int flag) {
  if ((flag & AT_REMOVEDIR) != 0) {
    return __wasilibc_rmdirat(fd, path);
  }
  return __wasilibc_unlinkat(fd, path);
}
