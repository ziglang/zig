// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <common/errno.h>

#include <sys/stat.h>

#include <wasi/api.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>

#include "stat_impl.h"

int __wasilibc_nocwd_fstatat(int fd, const char *restrict path, struct stat *restrict buf,
                             int flag) {
  // Create lookup properties.
  __wasi_lookupflags_t lookup_flags = 0;
  if ((flag & AT_SYMLINK_NOFOLLOW) == 0)
    lookup_flags |= __WASI_LOOKUPFLAGS_SYMLINK_FOLLOW;

  // Perform system call.
  __wasi_filestat_t internal_stat;
  __wasi_errno_t error =
      __wasi_path_filestat_get(fd, lookup_flags, path, &internal_stat);
  if (error != 0) {
    errno = errno_fixup_directory(fd, error);
    return -1;
  }
  to_public_stat(&internal_stat, buf);
  return 0;
}
