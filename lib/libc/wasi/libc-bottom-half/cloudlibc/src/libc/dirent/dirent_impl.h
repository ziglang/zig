// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#ifndef DIRENT_DIRENT_IMPL_H
#define DIRENT_DIRENT_IMPL_H

#include <wasi/api.h>
#include <stddef.h>

struct dirent;

#define DIRENT_DEFAULT_BUFFER_SIZE 4096

struct _DIR {
  // Directory file descriptor and cookie.
  int fd;
  __wasi_dircookie_t cookie;

  // Read buffer.
  char *buffer;
  size_t buffer_processed;
  size_t buffer_size;
  size_t buffer_used;

  // Object returned by readdir().
  struct dirent *dirent;
  size_t dirent_size;
};

#endif
