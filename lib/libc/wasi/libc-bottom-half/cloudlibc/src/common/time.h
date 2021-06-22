// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#ifndef COMMON_TIME_H
#define COMMON_TIME_H

#include <common/limits.h>
#include <common/overflow.h>

#include <sys/time.h>

#include <wasi/api.h>
#include <stdbool.h>
#include <time.h>

#define NSEC_PER_SEC 1000000000

// Timezone agnostic conversion routines.
int __localtime_utc(time_t, struct tm *);
void __mktime_utc(const struct tm *, struct timespec *);

static inline bool is_leap(time_t year) {
  year %= 400;
  if (year < 0)
    year += 400;
  return ((year % 4) == 0 && (year % 100) != 0) || year == 100;
}

// Gets the length of the months in a year.
static inline const char *get_months(time_t year) {
  static const char leap[12] = {
      31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
  };
  static const char common[12] = {
      31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
  };
  return is_leap(year) ? leap : common;
}

// Gets the cumulative length of the months in a year.
static inline const short *get_months_cumulative(time_t year) {
  static const short leap[13] = {
      0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366,
  };
  static const short common[13] = {
      0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365,
  };
  return is_leap(year) ? leap : common;
}

static inline short get_ydays(time_t year) {
  return is_leap(year) ? 366 : 365;
}

static inline bool timespec_to_timestamp_exact(
    const struct timespec *timespec, __wasi_timestamp_t *timestamp) {
  // Invalid nanoseconds field.
  if (timespec->tv_nsec < 0 || timespec->tv_nsec >= NSEC_PER_SEC)
    return false;

  // Timestamps before the Epoch are not supported.
  if (timespec->tv_sec < 0)
    return false;

  // Make sure our timestamp does not overflow.
  return !mul_overflow(timespec->tv_sec, NSEC_PER_SEC, timestamp) &&
         !add_overflow(*timestamp, timespec->tv_nsec, timestamp);
}

static inline bool timespec_to_timestamp_clamp(
    const struct timespec *timespec, __wasi_timestamp_t *timestamp) {
  // Invalid nanoseconds field.
  if (timespec->tv_nsec < 0 || timespec->tv_nsec >= NSEC_PER_SEC)
    return false;

  if (timespec->tv_sec < 0) {
    // Timestamps before the Epoch are not supported.
    *timestamp = 0;
  } else if (mul_overflow(timespec->tv_sec, NSEC_PER_SEC, timestamp) ||
             add_overflow(*timestamp, timespec->tv_nsec, timestamp)) {
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
