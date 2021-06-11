// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <common/errno.h>

#include <wasi/api.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

int __wasilibc_nocwd_renameat(int oldfd, const char *old, int newfd, const char *new) {
  __wasi_errno_t error = __wasi_path_rename(oldfd, old, newfd, new);
  if (error != 0) {
    errno = errno_fixup_directory(oldfd, errno_fixup_directory(newfd, error));
    return -1;
  }
  return 0;
}
