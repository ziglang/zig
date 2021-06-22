//===----------------------------------------------------------------------===////
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===////

#ifndef FILESYSTEM_COMMON_H
#define FILESYSTEM_COMMON_H

#include "__config"
#include "filesystem"
#include "array"
#include "chrono"
#include "climits"
#include "cstdlib"
#include "ctime"

#if !defined(_LIBCPP_WIN32API)
# include <unistd.h>
# include <sys/stat.h>
# include <sys/statvfs.h>
# include <sys/time.h> // for ::utimes as used in __last_write_time
# include <fcntl.h>    /* values for fchmodat */
#endif

#include "../include/apple_availability.h"

#if !defined(__APPLE__)
// We can use the presence of UTIME_OMIT to detect platforms that provide
// utimensat.
#if defined(UTIME_OMIT)
#define _LIBCPP_USE_UTIMENSAT
#endif
#endif

#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#endif

#if defined(_LIBCPP_WIN32API)
#define PS(x) (L##x)
#else
#define PS(x) (x)
#endif

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

namespace detail {

#if defined(_LIBCPP_WIN32API)
// Non anonymous, to allow access from two translation units.
errc __win_err_to_errc(int err);
#endif

namespace {

static string format_string_imp(const char* msg, ...) {
  // we might need a second shot at this, so pre-emptivly make a copy
  struct GuardVAList {
    va_list& target;
    bool active = true;
    GuardVAList(va_list& tgt) : target(tgt), active(true) {}
    void clear() {
      if (active)
        va_end(target);
      active = false;
    }
    ~GuardVAList() {
      if (active)
        va_end(target);
    }
  };
  va_list args;
  va_start(args, msg);
  GuardVAList args_guard(args);

  va_list args_cp;
  va_copy(args_cp, args);
  GuardVAList args_copy_guard(args_cp);

  std::string result;

  array<char, 256> local_buff;
  size_t size_with_null = local_buff.size();
  auto ret = ::vsnprintf(local_buff.data(), size_with_null, msg, args_cp);

  args_copy_guard.clear();

  // handle empty expansion
  if (ret == 0)
    return result;
  if (static_cast<size_t>(ret) < size_with_null) {
    result.assign(local_buff.data(), static_cast<size_t>(ret));
    return result;
  }

  // we did not provide a long enough buffer on our first attempt. The
  // return value is the number of bytes (excluding the null byte) that are
  // needed for formatting.
  size_with_null = static_cast<size_t>(ret) + 1;
  result.__resize_default_init(size_with_null - 1);
  ret = ::vsnprintf(&result[0], size_with_null, msg, args);
  _LIBCPP_ASSERT(static_cast<size_t>(ret) == (size_with_null - 1), "TODO");

  return result;
}

const path::value_type* unwrap(path::string_type const& s) { return s.c_str(); }
const path::value_type* unwrap(path const& p) { return p.native().c_str(); }
template <class Arg>
Arg const& unwrap(Arg const& a) {
  static_assert(!is_class<Arg>::value, "cannot pass class here");
  return a;
}

template <class... Args>
string format_string(const char* fmt, Args const&... args) {
  return format_string_imp(fmt, unwrap(args)...);
}

error_code capture_errno() {
  _LIBCPP_ASSERT(errno, "Expected errno to be non-zero");
  return error_code(errno, generic_category());
}

#if defined(_LIBCPP_WIN32API)
error_code make_windows_error(int err) {
  return make_error_code(__win_err_to_errc(err));
}
#endif

template <class T>
T error_value();
template <>
_LIBCPP_CONSTEXPR_AFTER_CXX11 void error_value<void>() {}
template <>
bool error_value<bool>() {
  return false;
}
#if __SIZEOF_SIZE_T__ != __SIZEOF_LONG_LONG__
template <>
size_t error_value<size_t>() {
  return size_t(-1);
}
#endif
template <>
uintmax_t error_value<uintmax_t>() {
  return uintmax_t(-1);
}
template <>
_LIBCPP_CONSTEXPR_AFTER_CXX11 file_time_type error_value<file_time_type>() {
  return file_time_type::min();
}
template <>
path error_value<path>() {
  return {};
}

template <class T>
struct ErrorHandler {
  const char* func_name_;
  error_code* ec_ = nullptr;
  const path* p1_ = nullptr;
  const path* p2_ = nullptr;

  ErrorHandler(const char* fname, error_code* ec, const path* p1 = nullptr,
               const path* p2 = nullptr)
      : func_name_(fname), ec_(ec), p1_(p1), p2_(p2) {
    if (ec_)
      ec_->clear();
  }

  T report(const error_code& ec) const {
    if (ec_) {
      *ec_ = ec;
      return error_value<T>();
    }
    string what = string("in ") + func_name_;
    switch (bool(p1_) + bool(p2_)) {
    case 0:
      __throw_filesystem_error(what, ec);
    case 1:
      __throw_filesystem_error(what, *p1_, ec);
    case 2:
      __throw_filesystem_error(what, *p1_, *p2_, ec);
    }
    _LIBCPP_UNREACHABLE();
  }

  template <class... Args>
  T report(const error_code& ec, const char* msg, Args const&... args) const {
    if (ec_) {
      *ec_ = ec;
      return error_value<T>();
    }
    string what =
        string("in ") + func_name_ + ": " + format_string(msg, args...);
    switch (bool(p1_) + bool(p2_)) {
    case 0:
      __throw_filesystem_error(what, ec);
    case 1:
      __throw_filesystem_error(what, *p1_, ec);
    case 2:
      __throw_filesystem_error(what, *p1_, *p2_, ec);
    }
    _LIBCPP_UNREACHABLE();
  }

  T report(errc const& err) const { return report(make_error_code(err)); }

  template <class... Args>
  T report(errc const& err, const char* msg, Args const&... args) const {
    return report(make_error_code(err), msg, args...);
  }

private:
  ErrorHandler(ErrorHandler const&) = delete;
  ErrorHandler& operator=(ErrorHandler const&) = delete;
};

using chrono::duration;
using chrono::duration_cast;

using TimeSpec = struct timespec;
using TimeVal = struct timeval;
using StatT = struct stat;

template <class FileTimeT, class TimeT,
          bool IsFloat = is_floating_point<typename FileTimeT::rep>::value>
struct time_util_base {
  using rep = typename FileTimeT::rep;
  using fs_duration = typename FileTimeT::duration;
  using fs_seconds = duration<rep>;
  using fs_nanoseconds = duration<rep, nano>;
  using fs_microseconds = duration<rep, micro>;

  static constexpr rep max_seconds =
      duration_cast<fs_seconds>(FileTimeT::duration::max()).count();

  static constexpr rep max_nsec =
      duration_cast<fs_nanoseconds>(FileTimeT::duration::max() -
                                    fs_seconds(max_seconds))
          .count();

  static constexpr rep min_seconds =
      duration_cast<fs_seconds>(FileTimeT::duration::min()).count();

  static constexpr rep min_nsec_timespec =
      duration_cast<fs_nanoseconds>(
          (FileTimeT::duration::min() - fs_seconds(min_seconds)) +
          fs_seconds(1))
          .count();

private:
#if _LIBCPP_STD_VER > 11 && !defined(_LIBCPP_HAS_NO_CXX14_CONSTEXPR)
  static constexpr fs_duration get_min_nsecs() {
    return duration_cast<fs_duration>(
        fs_nanoseconds(min_nsec_timespec) -
        duration_cast<fs_nanoseconds>(fs_seconds(1)));
  }
  // Static assert that these values properly round trip.
  static_assert(fs_seconds(min_seconds) + get_min_nsecs() ==
                    FileTimeT::duration::min(),
                "value doesn't roundtrip");

  static constexpr bool check_range() {
    // This kinda sucks, but it's what happens when we don't have __int128_t.
    if (sizeof(TimeT) == sizeof(rep)) {
      typedef duration<long long, ratio<3600 * 24 * 365> > Years;
      return duration_cast<Years>(fs_seconds(max_seconds)) > Years(250) &&
             duration_cast<Years>(fs_seconds(min_seconds)) < Years(-250);
    }
    return max_seconds >= numeric_limits<TimeT>::max() &&
           min_seconds <= numeric_limits<TimeT>::min();
  }
  static_assert(check_range(), "the representable range is unacceptable small");
#endif
};

template <class FileTimeT, class TimeT>
struct time_util_base<FileTimeT, TimeT, true> {
  using rep = typename FileTimeT::rep;
  using fs_duration = typename FileTimeT::duration;
  using fs_seconds = duration<rep>;
  using fs_nanoseconds = duration<rep, nano>;
  using fs_microseconds = duration<rep, micro>;

  static const rep max_seconds;
  static const rep max_nsec;
  static const rep min_seconds;
  static const rep min_nsec_timespec;
};

template <class FileTimeT, class TimeT>
const typename FileTimeT::rep
    time_util_base<FileTimeT, TimeT, true>::max_seconds =
        duration_cast<fs_seconds>(FileTimeT::duration::max()).count();

template <class FileTimeT, class TimeT>
const typename FileTimeT::rep time_util_base<FileTimeT, TimeT, true>::max_nsec =
    duration_cast<fs_nanoseconds>(FileTimeT::duration::max() -
                                  fs_seconds(max_seconds))
        .count();

template <class FileTimeT, class TimeT>
const typename FileTimeT::rep
    time_util_base<FileTimeT, TimeT, true>::min_seconds =
        duration_cast<fs_seconds>(FileTimeT::duration::min()).count();

template <class FileTimeT, class TimeT>
const typename FileTimeT::rep
    time_util_base<FileTimeT, TimeT, true>::min_nsec_timespec =
        duration_cast<fs_nanoseconds>((FileTimeT::duration::min() -
                                       fs_seconds(min_seconds)) +
                                      fs_seconds(1))
            .count();

template <class FileTimeT, class TimeT, class TimeSpecT>
struct time_util : time_util_base<FileTimeT, TimeT> {
  using Base = time_util_base<FileTimeT, TimeT>;
  using Base::max_nsec;
  using Base::max_seconds;
  using Base::min_nsec_timespec;
  using Base::min_seconds;

  using typename Base::fs_duration;
  using typename Base::fs_microseconds;
  using typename Base::fs_nanoseconds;
  using typename Base::fs_seconds;

public:
  template <class CType, class ChronoType>
  static _LIBCPP_CONSTEXPR_AFTER_CXX11 bool checked_set(CType* out,
                                                        ChronoType time) {
    using Lim = numeric_limits<CType>;
    if (time > Lim::max() || time < Lim::min())
      return false;
    *out = static_cast<CType>(time);
    return true;
  }

  static _LIBCPP_CONSTEXPR_AFTER_CXX11 bool is_representable(TimeSpecT tm) {
    if (tm.tv_sec >= 0) {
      return tm.tv_sec < max_seconds ||
             (tm.tv_sec == max_seconds && tm.tv_nsec <= max_nsec);
    } else if (tm.tv_sec == (min_seconds - 1)) {
      return tm.tv_nsec >= min_nsec_timespec;
    } else {
      return tm.tv_sec >= min_seconds;
    }
  }

  static _LIBCPP_CONSTEXPR_AFTER_CXX11 bool is_representable(FileTimeT tm) {
    auto secs = duration_cast<fs_seconds>(tm.time_since_epoch());
    auto nsecs = duration_cast<fs_nanoseconds>(tm.time_since_epoch() - secs);
    if (nsecs.count() < 0) {
      secs = secs + fs_seconds(1);
      nsecs = nsecs + fs_seconds(1);
    }
    using TLim = numeric_limits<TimeT>;
    if (secs.count() >= 0)
      return secs.count() <= TLim::max();
    return secs.count() >= TLim::min();
  }

  static _LIBCPP_CONSTEXPR_AFTER_CXX11 FileTimeT
  convert_from_timespec(TimeSpecT tm) {
    if (tm.tv_sec >= 0 || tm.tv_nsec == 0) {
      return FileTimeT(fs_seconds(tm.tv_sec) +
                       duration_cast<fs_duration>(fs_nanoseconds(tm.tv_nsec)));
    } else { // tm.tv_sec < 0
      auto adj_subsec = duration_cast<fs_duration>(fs_seconds(1) -
                                                   fs_nanoseconds(tm.tv_nsec));
      auto Dur = fs_seconds(tm.tv_sec + 1) - adj_subsec;
      return FileTimeT(Dur);
    }
  }

  template <class SubSecT>
  static _LIBCPP_CONSTEXPR_AFTER_CXX11 bool
  set_times_checked(TimeT* sec_out, SubSecT* subsec_out, FileTimeT tp) {
    auto dur = tp.time_since_epoch();
    auto sec_dur = duration_cast<fs_seconds>(dur);
    auto subsec_dur = duration_cast<fs_nanoseconds>(dur - sec_dur);
    // The tv_nsec and tv_usec fields must not be negative so adjust accordingly
    if (subsec_dur.count() < 0) {
      if (sec_dur.count() > min_seconds) {
        sec_dur = sec_dur - fs_seconds(1);
        subsec_dur = subsec_dur + fs_seconds(1);
      } else {
        subsec_dur = fs_nanoseconds::zero();
      }
    }
    return checked_set(sec_out, sec_dur.count()) &&
           checked_set(subsec_out, subsec_dur.count());
  }
  static _LIBCPP_CONSTEXPR_AFTER_CXX11 bool convert_to_timespec(TimeSpecT& dest,
                                                                FileTimeT tp) {
    if (!is_representable(tp))
      return false;
    return set_times_checked(&dest.tv_sec, &dest.tv_nsec, tp);
  }
};

using fs_time = time_util<file_time_type, time_t, TimeSpec>;

#if defined(__APPLE__)
inline TimeSpec extract_mtime(StatT const& st) { return st.st_mtimespec; }
inline TimeSpec extract_atime(StatT const& st) { return st.st_atimespec; }
#elif defined(__MVS__)
inline TimeSpec extract_mtime(StatT const& st) {
  TimeSpec TS = {st.st_mtime, 0};
  return TS;
}
inline TimeSpec extract_atime(StatT const& st) {
  TimeSpec TS = {st.st_atime, 0};
  return TS;
}
#else
inline TimeSpec extract_mtime(StatT const& st) { return st.st_mtim; }
inline TimeSpec extract_atime(StatT const& st) { return st.st_atim; }
#endif

inline TimeVal make_timeval(TimeSpec const& ts) {
  using namespace chrono;
  auto Convert = [](long nsec) {
    using int_type = decltype(std::declval<TimeVal>().tv_usec);
    auto dur = duration_cast<microseconds>(nanoseconds(nsec)).count();
    return static_cast<int_type>(dur);
  };
  TimeVal TV = {};
  TV.tv_sec = ts.tv_sec;
  TV.tv_usec = Convert(ts.tv_nsec);
  return TV;
}

inline bool posix_utimes(const path& p, std::array<TimeSpec, 2> const& TS,
                  error_code& ec) {
  TimeVal ConvertedTS[2] = {make_timeval(TS[0]), make_timeval(TS[1])};
  if (::utimes(p.c_str(), ConvertedTS) == -1) {
    ec = capture_errno();
    return true;
  }
  return false;
}

#if defined(_LIBCPP_USE_UTIMENSAT)
bool posix_utimensat(const path& p, std::array<TimeSpec, 2> const& TS,
                     error_code& ec) {
  if (::utimensat(AT_FDCWD, p.c_str(), TS.data(), 0) == -1) {
    ec = capture_errno();
    return true;
  }
  return false;
}
#endif

bool set_file_times(const path& p, std::array<TimeSpec, 2> const& TS,
                    error_code& ec) {
#if !defined(_LIBCPP_USE_UTIMENSAT)
  return posix_utimes(p, TS, ec);
#else
  return posix_utimensat(p, TS, ec);
#endif
}

} // namespace
} // end namespace detail

_LIBCPP_END_NAMESPACE_FILESYSTEM

#endif // FILESYSTEM_COMMON_H
