// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <sys/stat.h>

#include <wasi/api.h>
#include <errno.h>

#include "stat_impl.h"

int futimens(int fd, const struct timespec *times) {
  // Convert timestamps and extract NOW/OMIT flags.
  __wasi_timestamp_t st_atim;
  __wasi_timestamp_t st_mtim;
  __wasi_fstflags_t flags;
  if (!utimens_get_timestamps(times, &st_atim, &st_mtim, &flags)) {
    errno = EINVAL;
    return -1;
  }

  // Perform system call.
  __wasi_errno_t error = __wasi_fd_filestat_set_times(fd, st_atim, st_mtim, flags);
  if (error != 0) {
    errno = error;
    return -1;
  }
  return 0;
}
