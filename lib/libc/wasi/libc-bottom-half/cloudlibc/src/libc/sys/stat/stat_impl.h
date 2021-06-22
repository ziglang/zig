// Copyright (c) 2015-2017 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#ifndef SYS_STAT_STAT_IMPL_H
#define SYS_STAT_STAT_IMPL_H

#include <common/time.h>

#include <sys/stat.h>

#include <assert.h>
#include <wasi/api.h>
#include <stdbool.h>

static_assert(S_ISBLK(S_IFBLK), "Value mismatch");
static_assert(S_ISCHR(S_IFCHR), "Value mismatch");
static_assert(S_ISDIR(S_IFDIR), "Value mismatch");
static_assert(S_ISFIFO(S_IFIFO), "Value mismatch");
static_assert(S_ISLNK(S_IFLNK), "Value mismatch");
static_assert(S_ISREG(S_IFREG), "Value mismatch");
static_assert(S_ISSOCK(S_IFSOCK), "Value mismatch");

static inline void to_public_stat(const __wasi_filestat_t *in,
                                  struct stat *out) {
  // Ensure that we don't truncate any values.
  static_assert(sizeof(in->dev) == sizeof(out->st_dev), "Size mismatch");
  static_assert(sizeof(in->ino) == sizeof(out->st_ino), "Size mismatch");
  /*
   * The non-standard __st_filetype field appears to only be used for shared
   * memory, which we don't currently support.
   */
  /* nlink_t is 64-bit on wasm32, following the x32 ABI. */
  static_assert(sizeof(in->nlink) <= sizeof(out->st_nlink), "Size shortfall");
  static_assert(sizeof(in->size) == sizeof(out->st_size), "Size mismatch");

  *out = (struct stat){
      .st_dev = in->dev,
      .st_ino = in->ino,
      .st_nlink = in->nlink,
      .st_size = in->size,
      .st_atim = timestamp_to_timespec(in->atim),
      .st_mtim = timestamp_to_timespec(in->mtim),
      .st_ctim = timestamp_to_timespec(in->ctim),
  };

  // Convert file type to legacy types encoded in st_mode.
  switch (in->filetype) {
    case __WASI_FILETYPE_BLOCK_DEVICE:
      out->st_mode |= S_IFBLK;
      break;
    case __WASI_FILETYPE_CHARACTER_DEVICE:
      out->st_mode |= S_IFCHR;
      break;
    case __WASI_FILETYPE_DIRECTORY:
      out->st_mode |= S_IFDIR;
      break;
    case __WASI_FILETYPE_REGULAR_FILE:
      out->st_mode |= S_IFREG;
      break;
    case __WASI_FILETYPE_SOCKET_DGRAM:
    case __WASI_FILETYPE_SOCKET_STREAM:
      out->st_mode |= S_IFSOCK;
      break;
    case __WASI_FILETYPE_SYMBOLIC_LINK:
      out->st_mode |= S_IFLNK;
      break;
  }
}

static inline bool utimens_get_timestamps(const struct timespec *times,
                                          __wasi_timestamp_t *st_atim,
                                          __wasi_timestamp_t *st_mtim,
                                          __wasi_fstflags_t *flags) {
  if (times == NULL) {
    // Update both timestamps.
    *flags = __WASI_FSTFLAGS_ATIM_NOW | __WASI_FSTFLAGS_MTIM_NOW;
  } else {
    // Set individual timestamps.
    *flags = 0;
    switch (times[0].tv_nsec) {
      case UTIME_NOW:
        *flags |= __WASI_FSTFLAGS_ATIM_NOW;
        break;
      case UTIME_OMIT:
        break;
      default:
        *flags |= __WASI_FSTFLAGS_ATIM;
        if (!timespec_to_timestamp_exact(&times[0], st_atim))
          return false;
        break;
    }

    switch (times[1].tv_nsec) {
      case UTIME_NOW:
        *flags |= __WASI_FSTFLAGS_MTIM_NOW;
        break;
      case UTIME_OMIT:
        break;
      default:
        *flags |= __WASI_FSTFLAGS_MTIM;
        if (!timespec_to_timestamp_exact(&times[1], st_mtim))
          return false;
        break;
    }
  }
  return true;
}

#endif
