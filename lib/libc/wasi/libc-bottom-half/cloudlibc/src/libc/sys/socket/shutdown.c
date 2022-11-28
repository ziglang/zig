// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <sys/socket.h>

#include <assert.h>
#include <wasi/api.h>
#include <errno.h>

static_assert(SHUT_RD == __WASI_SDFLAGS_RD, "Value mismatch");
static_assert(SHUT_WR == __WASI_SDFLAGS_WR, "Value mismatch");

int shutdown(int socket, int how) {
  // Validate shutdown flags.
  if (how != SHUT_RD && how != SHUT_WR && how != SHUT_RDWR) {
    errno = EINVAL;
    return -1;
  }

  __wasi_errno_t error = __wasi_sock_shutdown(socket, how);
  if (error != 0) {
    errno = error;
    return -1;
  }
  return error;
}
