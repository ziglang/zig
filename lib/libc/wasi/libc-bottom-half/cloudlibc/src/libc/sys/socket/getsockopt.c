// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <sys/socket.h>

#include <wasi/api.h>
#include <errno.h>
#include <string.h>

int getsockopt(int socket, int level, int option_name,
               void *restrict option_value, socklen_t *restrict option_len) {
  // Only support SOL_SOCKET options for now.
  if (level != SOL_SOCKET) {
    errno = ENOPROTOOPT;
    return -1;
  }

  int value;
  switch (option_name) {
    case SO_TYPE: {
      // Return the type of the socket. This information can simply be
      // obtained by looking at the file descriptor type.
      __wasi_fdstat_t fsb;
      if (__wasi_fd_fdstat_get(socket, &fsb) != 0) {
        errno = EBADF;
        return -1;
      }
      if (fsb.fs_filetype != __WASI_FILETYPE_SOCKET_DGRAM &&
          fsb.fs_filetype != __WASI_FILETYPE_SOCKET_STREAM) {
        errno = ENOTSOCK;
        return -1;
      }
      value = fsb.fs_filetype;
      break;
    }
    default: {
      errno = ENOPROTOOPT;
      return -1;
    }
  }

  // Copy out integer value.
  memcpy(option_value, &value,
         *option_len < sizeof(int) ? *option_len : sizeof(int));
  *option_len = sizeof(int);
  return 0;
}
