// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <assert.h>
#include <wasi/api.h>
#include <wasi/libc.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>

static_assert(O_APPEND == __WASI_FDFLAGS_APPEND, "Value mismatch");
static_assert(O_DSYNC == __WASI_FDFLAGS_DSYNC, "Value mismatch");
static_assert(O_NONBLOCK == __WASI_FDFLAGS_NONBLOCK, "Value mismatch");
static_assert(O_RSYNC == __WASI_FDFLAGS_RSYNC, "Value mismatch");
static_assert(O_SYNC == __WASI_FDFLAGS_SYNC, "Value mismatch");

static_assert(O_CREAT >> 12 == __WASI_OFLAGS_CREAT, "Value mismatch");
static_assert(O_DIRECTORY >> 12 == __WASI_OFLAGS_DIRECTORY, "Value mismatch");
static_assert(O_EXCL >> 12 == __WASI_OFLAGS_EXCL, "Value mismatch");
static_assert(O_TRUNC >> 12 == __WASI_OFLAGS_TRUNC, "Value mismatch");

int __wasilibc_nocwd_openat_nomode(int fd, const char *path, int oflag) {
  // Compute rights corresponding with the access modes provided.
  // Attempt to obtain all rights, except the ones that contradict the
  // access mode provided to openat().
  __wasi_rights_t max =
      ~(__WASI_RIGHTS_FD_DATASYNC | __WASI_RIGHTS_FD_READ |
        __WASI_RIGHTS_FD_WRITE | __WASI_RIGHTS_FD_ALLOCATE |
        __WASI_RIGHTS_FD_READDIR | __WASI_RIGHTS_FD_FILESTAT_SET_SIZE);
  switch (oflag & O_ACCMODE) {
    case O_RDONLY:
    case O_RDWR:
    case O_WRONLY:
      if ((oflag & O_RDONLY) != 0) {
        max |= __WASI_RIGHTS_FD_READ | __WASI_RIGHTS_FD_READDIR;
      }
      if ((oflag & O_WRONLY) != 0) {
        max |= __WASI_RIGHTS_FD_DATASYNC | __WASI_RIGHTS_FD_WRITE |
               __WASI_RIGHTS_FD_ALLOCATE |
               __WASI_RIGHTS_FD_FILESTAT_SET_SIZE;
      }
      break;
    case O_EXEC:
      break;
    case O_SEARCH:
      break;
    default:
      errno = EINVAL;
      return -1;
  }

  // Ensure that we can actually obtain the minimal rights needed.
  __wasi_fdstat_t fsb_cur;
  __wasi_errno_t error = __wasi_fd_fdstat_get(fd, &fsb_cur);
  if (error != 0) {
    errno = error;
    return -1;
  }

  // Path lookup properties.
  __wasi_lookupflags_t lookup_flags = 0;
  if ((oflag & O_NOFOLLOW) == 0)
    lookup_flags |= __WASI_LOOKUPFLAGS_SYMLINK_FOLLOW;

  // Open file with appropriate rights.
  __wasi_fdflags_t fs_flags = oflag & 0xfff;
  __wasi_rights_t fs_rights_base = max & fsb_cur.fs_rights_inheriting;
  __wasi_rights_t fs_rights_inheriting = fsb_cur.fs_rights_inheriting;
  __wasi_fd_t newfd;
  error = __wasi_path_open(fd, lookup_flags, path,
                                 (oflag >> 12) & 0xfff,
                                 fs_rights_base, fs_rights_inheriting, fs_flags,
                                 &newfd);
  if (error != 0) {
    errno = error;
    return -1;
  }
  return newfd;
}
