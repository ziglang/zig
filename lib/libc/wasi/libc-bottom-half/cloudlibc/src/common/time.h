// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#ifndef COMMON_TIME_H
#define COMMON_TIME_H

#include <common/limits.h>

#include <sys/time.h>

#include <wasi/api.h>
#include <stdbool.h>
#include <time.h>

#define NSEC_PER_SEC 1000000000

static inline bool timespec_to_timestamp_exact(
    const struct timespec *timespec, __wasi_timestamp_t *timestamp) {
  // Invalid nanoseconds field.
  if (timespec->tv_nsec < 0 || timespec->tv_nsec >= NSEC_PER_SEC)
    return false;

  // Timestamps before the Epoch are not supported.
  if (timespec->tv_sec < 0)
    return false;

  // Make sure our timestamp does not overflow.
  return !__builtin_mul_overflow(timespec->tv_sec, NSEC_PER_SEC, timestamp) &&
         !__builtin_add_overflow(*timestamp, timespec->tv_nsec, timestamp);
}

static inline bool timespec_to_timestamp_clamp(
    const struct timespec *timespec, __wasi_timestamp_t *timestamp) {
  // Invalid nanoseconds field.
  if (timespec->tv_nsec < 0 || timespec->tv_nsec >= NSEC_PER_SEC)
    return false;

  if (timespec->tv_sec < 0) {
    // Timestamps before the Epoch are not supported.
    *timestamp = 0;
  } else if (__builtin_mul_overflow(timespec->tv_sec, NSEC_PER_SEC, timestamp) ||
             __builtin_add_overflow(*timestamp, timespec->tv_nsec, timestamp)) {
    // Make sure our timestamp does not overflow.
    *timestamp = NUMERIC_MAX(__wasi_timestamp_t);
  }
  return true;
}

static inline struct timespec timestamp_to_timespec(
    __wasi_timestamp_t timestamp) {
  // Decompose timestamp into seconds and nanoseconds.
  return (struct timespec){.tv_sec = timestamp / NSEC_PER_SEC,
                           .tv_nsec = timestamp % NSEC_PER_SEC};
}

static inline struct timeval timestamp_to_timeval(
    __wasi_timestamp_t timestamp) {
  struct timespec ts = timestamp_to_timespec(timestamp);
  return (struct timeval){.tv_sec = ts.tv_sec, ts.tv_nsec / 1000};
}

#endif
