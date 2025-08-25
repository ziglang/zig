// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <common/clock.h>
#include <common/time.h>

#include <assert.h>
#include <wasi/api.h>
#include <errno.h>
#include <time.h>

static_assert(TIMER_ABSTIME == __WASI_SUBCLOCKFLAGS_SUBSCRIPTION_CLOCK_ABSTIME,
              "Value mismatch");

int clock_nanosleep(clockid_t clock_id, int flags, const struct timespec *rqtp,
                    struct timespec *rmtp) {
  if ((flags & ~TIMER_ABSTIME) != 0)
    return EINVAL;

  // Prepare polling subscription.
  __wasi_subscription_t sub = {
      .u.tag = __WASI_EVENTTYPE_CLOCK,
      .u.u.clock.id = clock_id->id,
      .u.u.clock.flags = flags,
  };
  if (!timespec_to_timestamp_clamp(rqtp, &sub.u.u.clock.timeout))
    return EINVAL;

  // Block until polling event is triggered.
  size_t nevents;
  __wasi_event_t ev;
  __wasi_errno_t error = __wasi_poll_oneoff(&sub, &ev, 1, &nevents);
  return error == 0 && ev.error == 0 ? 0 : ENOTSUP;
}

weak_alias(clock_nanosleep, __clock_nanosleep);
