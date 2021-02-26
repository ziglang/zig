// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP_SUPPORT_IBM_NANOSLEEP_H
#define _LIBCPP_SUPPORT_IBM_NANOSLEEP_H

#include <unistd.h>

inline int nanosleep(const struct timespec* req, struct timespec* rem)
{
   // The nanosleep() function is not available on z/OS. Therefore, we will call
   // sleep() to sleep for whole seconds and usleep() to sleep for any remaining
   // fraction of a second. Any remaining nanoseconds will round up to the next
   // microsecond.

   useconds_t __micro_sec = (rem->tv_nsec + 999) / 1000;
   if (__micro_sec > 999999)
   {
     ++rem->tv_sec;
     __micro_sec -= 1000000;
   }
   while (rem->tv_sec)
      rem->tv_sec = sleep(rem->tv_sec);
   if (__micro_sec) {
     rem->tv_nsec = __micro_sec * 1000;
     return usleep(__micro_sec);
   }
   rem->tv_nsec = 0;
   return 0;
}

#endif // _LIBCPP_SUPPORT_IBM_NANOSLEEP_H
