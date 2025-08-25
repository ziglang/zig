// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <wasi/api.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int __wasilibc_nocwd_linkat(int fd1, const char *path1, int fd2, const char *path2, int flag) {
  // Create lookup properties.
  __wasi_lookupflags_t lookup1_flags = 0;
  if ((flag & AT_SYMLINK_FOLLOW) != 0)
    lookup1_flags |= __WASI_LOOKUPFLAGS_SYMLINK_FOLLOW;

  // Perform system call.
  __wasi_errno_t error = __wasi_path_link(fd1, lookup1_flags, path1, fd2, path2);
  if (error != 0) {
    errno = error;
    return -1;
  }
  return 0;
}
