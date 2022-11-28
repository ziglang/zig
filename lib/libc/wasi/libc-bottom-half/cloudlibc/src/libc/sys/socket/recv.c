// Copyright (c) 2015-2017 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <sys/socket.h>

#include <assert.h>
#include <wasi/api.h>
#include <errno.h>
#include <stdint.h>

static_assert(MSG_PEEK == __WASI_RIFLAGS_RECV_PEEK, "Value mismatch");
static_assert(MSG_WAITALL == __WASI_RIFLAGS_RECV_WAITALL, "Value mismatch");

ssize_t recv(int socket, void *restrict buffer, size_t length, int flags) {
  // Validate flags.
  if ((flags & ~(MSG_PEEK | MSG_WAITALL)) != 0) {
    errno = EOPNOTSUPP;
    return -1;
  }

  // Prepare input parameters.
  __wasi_iovec_t iov = {.buf = buffer, .buf_len = length};
  __wasi_iovec_t *ri_data = &iov;
  size_t ri_data_len = 1;
  __wasi_riflags_t ri_flags = flags;

  // Perform system call.
  size_t ro_datalen;
  __wasi_roflags_t ro_flags;
  __wasi_errno_t error = __wasi_sock_recv(socket,
                                          ri_data, ri_data_len, ri_flags,
                                          &ro_datalen,
                                          &ro_flags);
  if (error != 0) {
    errno = error;
    return -1;
  }
  return ro_datalen;
}
