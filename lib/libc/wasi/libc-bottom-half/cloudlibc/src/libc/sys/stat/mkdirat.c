// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <common/errno.h>

#include <sys/stat.h>

#include <wasi/api.h>
#include <errno.h>
#include <string.h>

int __wasilibc_nocwd_mkdirat_nomode(int fd, const char *path) {
  __wasi_errno_t error = __wasi_path_create_directory(fd, path);
  if (error != 0) {
    errno = errno_fixup_directory(fd, error);
    return -1;
  }
  return 0;
}
