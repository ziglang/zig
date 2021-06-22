// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <wasi/api.h>
#include <errno.h>
#include <sched.h>

int sched_yield(void) {
  __wasi_errno_t error = __wasi_sched_yield();
  if (error != 0) {
    errno = error;
    return -1;
  }
  return 0;
}
