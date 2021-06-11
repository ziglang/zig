// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <common/clock.h>
#include <common/time.h>

#include <wasi/api.h>
#include <errno.h>
#include <time.h>

int clock_getres(clockid_t clock_id, struct timespec *res) {
  __wasi_timestamp_t ts;
  __wasi_errno_t error = __wasi_clock_res_get(clock_id->id, &ts);
  if (error != 0) {
    errno = error;
    return -1;
  }
  *res = timestamp_to_timespec(ts);
  return 0;
}
