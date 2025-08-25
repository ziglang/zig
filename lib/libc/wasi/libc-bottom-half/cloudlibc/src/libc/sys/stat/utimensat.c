// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <sys/stat.h>

#include <wasi/api.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>

#include "stat_impl.h"

int __wasilibc_nocwd_utimensat(int fd, const char *path, const struct timespec times[2],
                               int flag) {
  // Convert timestamps and extract NOW/OMIT flags.
  __wasi_timestamp_t st_atim;
  __wasi_timestamp_t st_mtim;
  __wasi_fstflags_t flags;
  if (!utimens_get_timestamps(times, &st_atim, &st_mtim, &flags)) {
    errno = EINVAL;
    return -1;
  }

  // Create lookup properties.
  __wasi_lookupflags_t lookup_flags = 0;
  if ((flag & AT_SYMLINK_NOFOLLOW) == 0)
    lookup_flags |= __WASI_LOOKUPFLAGS_SYMLINK_FOLLOW;

  // Perform system call.
  __wasi_errno_t error =
      __wasi_path_filestat_set_times(fd, lookup_flags, path, st_atim, st_mtim, flags);
  if (error != 0) {
    errno = error;
    return -1;
  }
  return 0;
}
