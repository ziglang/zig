// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <wasi/api.h>
#include <dirent.h>
#include <errno.h>
#include <stdlib.h>

#include "dirent_impl.h"

DIR *fdopendir(int fd) {
  // Allocate new directory object and read buffer.
  DIR *dirp = malloc(sizeof(*dirp));
  if (dirp == NULL)
    return NULL;
  dirp->buffer = malloc(DIRENT_DEFAULT_BUFFER_SIZE);
  if (dirp->buffer == NULL) {
    free(dirp);
    return NULL;
  }

  // Ensure that this is really a directory by already loading the first
  // chunk of data.
  __wasi_errno_t error =
      // TODO: Remove the cast on `dirp->buffer` once the witx is updated with char8 support.
      __wasi_fd_readdir(fd, (uint8_t *)dirp->buffer, DIRENT_DEFAULT_BUFFER_SIZE,
                                __WASI_DIRCOOKIE_START, &dirp->buffer_used);
  if (error != 0) {
    free(dirp->buffer);
    free(dirp);
    errno = error;
    return NULL;
  }

  // Initialize other members.
  dirp->fd = fd;
  dirp->cookie = __WASI_DIRCOOKIE_START;
  dirp->buffer_processed = 0;
  dirp->buffer_size = DIRENT_DEFAULT_BUFFER_SIZE;
  dirp->dirent = NULL;
  dirp->dirent_size = 1;
  return dirp;
}
