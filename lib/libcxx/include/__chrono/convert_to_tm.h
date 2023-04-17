// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___CHRONO_CONVERT_TO_TM_H
#define _LIBCPP___CHRONO_CONVERT_TO_TM_H

#include <__chrono/day.h>
#include <__chrono/duration.h>
#include <__chrono/hh_mm_ss.h>
#include <__chrono/month.h>
#include <__chrono/month_weekday.h>
#include <__chrono/monthday.h>
#include <__chrono/statically_widen.h>
#include <__chrono/system_clock.h>
#include <__chrono/time_point.h>
#include <__chrono/weekday.h>
#include <__chrono/year.h>
#include <__chrono/year_month.h>
#include <__chrono/year_month_day.h>
#include <__chrono/year_month_weekday.h>
#include <__concepts/same_as.h>
#include <__config>
#include <__memory/addressof.h>
#include <cstdint>
#include <ctime>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// Conerts a chrono date and weekday to a given _Tm type.
//
// This is an implementation detail for the function
//   template <class _Tm, class _ChronoT>
//   _Tm __convert_to_tm(const _ChronoT& __value)
//
// This manually converts the two values to the proper type. It is possible to
// convert from sys_days to time_t and then to _Tm. But this leads to the Y2K
// bug when time_t is a 32-bit signed integer. Chrono considers years beyond
// the year 2038 valid, so instead do the transformation manually.
template <class _Tm, class _Date>
  requires(same_as<_Date, chrono::year_month_day> || same_as<_Date, chrono::year_month_day_last>)
_LIBCPP_HIDE_FROM_ABI _Tm __convert_to_tm(const _Date& __date, chrono::weekday __weekday) {
  _Tm __result = {};
#  ifdef __GLIBC__
  __result.tm_zone = "UTC";
#  endif
  __result.tm_year = static_cast<int>(__date.year()) - 1900;
  __result.tm_mon  = static_cast<unsigned>(__date.month()) - 1;
  __result.tm_mday = static_cast<unsigned>(__date.day());
  __result.tm_wday = static_cast<unsigned>(__weekday.c_encoding());
  __result.tm_yday =
      (static_cast<chrono::sys_days>(__date) -
       static_cast<chrono::sys_days>(chrono::year_month_day{__date.year(), chrono::January, chrono::day{1}}))
          .count();

  return __result;
}

// Convert a chrono (calendar) time point, or dururation to the given _Tm type,
// which must have the same properties as std::tm.
template <class _Tm, class _ChronoT>
_LIBCPP_HIDE_FROM_ABI _Tm __convert_to_tm(const _ChronoT& __value) {
  _Tm __result = {};
#  ifdef __GLIBC__
  __result.tm_zone = "UTC";
#  endif

  if constexpr (chrono::__is_duration<_ChronoT>::value) {
    // [time.format]/6
    //   ...  However, if a flag refers to a "time of day" (e.g. %H, %I, %p,
    //   etc.), then a specialization of duration is interpreted as the time of
    //   day elapsed since midnight.
    uint64_t __sec = chrono::duration_cast<chrono::seconds>(__value).count();
    __sec %= 24 * 3600;
    __result.tm_hour = __sec / 3600;
    __sec %= 3600;
    __result.tm_min = __sec / 60;
    __result.tm_sec = __sec % 60;
  } else if constexpr (same_as<_ChronoT, chrono::day>)
    __result.tm_mday = static_cast<unsigned>(__value);
  else if constexpr (same_as<_ChronoT, chrono::month>)
    __result.tm_mon = static_cast<unsigned>(__value) - 1;
  else if constexpr (same_as<_ChronoT, chrono::year>)
    __result.tm_year = static_cast<int>(__value) - 1900;
  else if constexpr (same_as<_ChronoT, chrono::weekday>)
    __result.tm_wday = __value.c_encoding();
  else if constexpr (same_as<_ChronoT, chrono::weekday_indexed> || same_as<_ChronoT, chrono::weekday_last>)
    __result.tm_wday = __value.weekday().c_encoding();
  else if constexpr (same_as<_ChronoT, chrono::month_day>) {
    __result.tm_mday = static_cast<unsigned>(__value.day());
    __result.tm_mon  = static_cast<unsigned>(__value.month()) - 1;
  } else if constexpr (same_as<_ChronoT, chrono::month_day_last>) {
    __result.tm_mon = static_cast<unsigned>(__value.month()) - 1;
  } else if constexpr (same_as<_ChronoT, chrono::month_weekday> || same_as<_ChronoT, chrono::month_weekday_last>) {
    __result.tm_wday = __value.weekday_indexed().weekday().c_encoding();
    __result.tm_mon  = static_cast<unsigned>(__value.month()) - 1;
  } else if constexpr (same_as<_ChronoT, chrono::year_month>) {
    __result.tm_year = static_cast<int>(__value.year()) - 1900;
    __result.tm_mon  = static_cast<unsigned>(__value.month()) - 1;
  } else if constexpr (same_as<_ChronoT, chrono::year_month_day> || same_as<_ChronoT, chrono::year_month_day_last>) {
    return std::__convert_to_tm<_Tm>(
        chrono::year_month_day{__value}, chrono::weekday{static_cast<chrono::sys_days>(__value)});
  } else if constexpr (same_as<_ChronoT, chrono::year_month_weekday> ||
                       same_as<_ChronoT, chrono::year_month_weekday_last>) {
    return std::__convert_to_tm<_Tm>(chrono::year_month_day{static_cast<chrono::sys_days>(__value)}, __value.weekday());
  } else
    static_assert(sizeof(_ChronoT) == 0, "Add the missing type specialization");

  return __result;
}

#endif //if _LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___CHRONO_CONVERT_TO_TM_H
