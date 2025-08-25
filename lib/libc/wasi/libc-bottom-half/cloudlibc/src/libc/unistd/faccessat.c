// Copyright (c) 2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <wasi/api.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int __wasilibc_nocwd_faccessat(int fd, const char *path, int amode, int flag) {
  // Validate function parameters.
  if ((amode & ~(F_OK | R_OK | W_OK | X_OK)) != 0 ||
      (flag & ~AT_EACCESS) != 0) {
    errno = EINVAL;
    return -1;
  }

  // Check for target file existence and obtain the file type.
  __wasi_lookupflags_t lookup_flags = __WASI_LOOKUPFLAGS_SYMLINK_FOLLOW;
  __wasi_filestat_t file;
  __wasi_errno_t error =
      __wasi_path_filestat_get(fd, lookup_flags, path, &file);
  if (error != 0) {
    errno = error;
    return -1;
  }

  // Test whether the requested access rights are present on the
  // directory file descriptor.
  if (amode != 0) {
    __wasi_fdstat_t directory;
    error = __wasi_fd_fdstat_get(fd, &directory);
    if (error != 0) {
      errno = error;
      return -1;
    }

    __wasi_rights_t min = 0;
    if ((amode & R_OK) != 0)
      min |= file.filetype == __WASI_FILETYPE_DIRECTORY
                 ? __WASI_RIGHTS_FD_READDIR
                 : __WASI_RIGHTS_FD_READ;
    if ((amode & W_OK) != 0)
      min |= __WASI_RIGHTS_FD_WRITE;

    if ((min & directory.fs_rights_inheriting) != min) {
      errno = EACCES;
      return -1;
    }
  }
  return 0;
}
