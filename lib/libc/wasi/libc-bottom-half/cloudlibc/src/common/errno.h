// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#ifndef COMMON_ERRNO_H
#define COMMON_ERRNO_H

#include <wasi/api.h>

// WASI syscalls should just return ENOTDIR if that's what the problem is.
static inline __wasi_errno_t errno_fixup_directory(__wasi_fd_t fd,
                                                     __wasi_errno_t error) {
  return error;
}

// WASI syscalls should just return ENOTSOCK if that's what the problem is.
static inline __wasi_errno_t errno_fixup_socket(__wasi_fd_t fd,
                                                  __wasi_errno_t error) {
  return error;
}

#endif
