// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <assert.h>
#include <wasi/api.h>
#include <errno.h>
#include <fcntl.h>

static_assert(POSIX_FADV_DONTNEED == __WASI_ADVICE_DONTNEED,
              "Value mismatch");
static_assert(POSIX_FADV_NOREUSE == __WASI_ADVICE_NOREUSE, "Value mismatch");
static_assert(POSIX_FADV_NORMAL == __WASI_ADVICE_NORMAL, "Value mismatch");
static_assert(POSIX_FADV_RANDOM == __WASI_ADVICE_RANDOM, "Value mismatch");
static_assert(POSIX_FADV_SEQUENTIAL == __WASI_ADVICE_SEQUENTIAL,
              "Value mismatch");
static_assert(POSIX_FADV_WILLNEED == __WASI_ADVICE_WILLNEED,
              "Value mismatch");

int posix_fadvise(int fd, off_t offset, off_t len, int advice) {
  if (offset < 0 || len < 0)
    return EINVAL;
  return __wasi_fd_advise(fd, offset, len, advice);
}
