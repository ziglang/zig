// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <common/time.h>

#include <sys/time.h>

#include <wasi/api.h>

int gettimeofday(struct timeval *restrict tp, void *tz) {
  __wasi_timestamp_t ts = 0;
  (void)__wasi_clock_time_get(__WASI_CLOCKID_REALTIME, 1000, &ts);
  *tp = timestamp_to_timeval(ts);
  return 0;
}
