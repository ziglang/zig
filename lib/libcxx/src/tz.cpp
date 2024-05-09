//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// For information see https://libcxx.llvm.org/DesignDocs/TimeZone.html

#include <chrono>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>

// Contains a parser for the IANA time zone data files.
//
// These files can be found at https://data.iana.org/time-zones/ and are in the
// public domain. Information regarding the input can be found at
// https://data.iana.org/time-zones/tz-how-to.html and
// https://man7.org/linux/man-pages/man8/zic.8.html.
//
// As indicated at https://howardhinnant.github.io/date/tz.html#Installation
// For Windows another file seems to be required
// https://raw.githubusercontent.com/unicode-org/cldr/master/common/supplemental/windowsZones.xml
// This file seems to contain the mapping of Windows time zone name to IANA
// time zone names.
//
// However this article mentions another way to do the mapping on Windows
// https://devblogs.microsoft.com/oldnewthing/20210527-00/?p=105255
// This requires Windows 10 Version 1903, which was released in May of 2019
// and considered end of life in December 2020
// https://learn.microsoft.com/en-us/lifecycle/announcements/windows-10-1903-end-of-servicing
//
// TODO TZDB Implement the Windows mapping in tzdb::current_zone

_LIBCPP_BEGIN_NAMESPACE_STD

namespace chrono {

// This function is weak so it can be overriden in the tests. The
// declaration is in the test header test/support/test_tzdb.h
_LIBCPP_WEAK string_view __libcpp_tzdb_directory() {
#if defined(__linux__)
  return "/usr/share/zoneinfo/";
#else
// Zig patch: change this compilation error into a runtime crash.
//#  error "unknown path to the IANA Time Zone Database"
  abort();
#endif
}

[[nodiscard]] static bool __is_whitespace(int __c) { return __c == ' ' || __c == '\t'; }

static void __skip_optional_whitespace(istream& __input) {
  while (chrono::__is_whitespace(__input.peek()))
    __input.get();
}

static void __skip_mandatory_whitespace(istream& __input) {
  if (!chrono::__is_whitespace(__input.get()))
    std::__throw_runtime_error("corrupt tzdb: expected whitespace");

  chrono::__skip_optional_whitespace(__input);
}

static void __matches(istream& __input, char __expected) {
  if (std::tolower(__input.get()) != __expected)
    std::__throw_runtime_error((string("corrupt tzdb: expected character '") + __expected + '\'').c_str());
}

static void __matches(istream& __input, string_view __expected) {
  for (auto __c : __expected)
    if (std::tolower(__input.get()) != __c)
      std::__throw_runtime_error((string("corrupt tzdb: expected string '") + string(__expected) + '\'').c_str());
}

[[nodiscard]] static string __parse_string(istream& __input) {
  string __result;
  while (true) {
    int __c = __input.get();
    switch (__c) {
    case ' ':
    case '\t':
    case '\n':
      __input.unget();
      [[fallthrough]];
    case istream::traits_type::eof():
      if (__result.empty())
        std::__throw_runtime_error("corrupt tzdb: expected a string");

      return __result;

    default:
      __result.push_back(__c);
    }
  }
}

static string __parse_version(istream& __input) {
  // The first line in tzdata.zi contains
  //    # version YYYYw
  // The parser expects this pattern
  // #\s*version\s*\(.*)
  // This part is not documented.
  chrono::__matches(__input, '#');
  chrono::__skip_optional_whitespace(__input);
  chrono::__matches(__input, "version");
  chrono::__skip_mandatory_whitespace(__input);
  return chrono::__parse_string(__input);
}

static tzdb __make_tzdb() {
  tzdb __result;

  filesystem::path __root = chrono::__libcpp_tzdb_directory();
  ifstream __tzdata{__root / "tzdata.zi"};

  __result.version = chrono::__parse_version(__tzdata);
  return __result;
}

//===----------------------------------------------------------------------===//
//                           Public API
//===----------------------------------------------------------------------===//

_LIBCPP_NODISCARD_EXT _LIBCPP_AVAILABILITY_TZDB _LIBCPP_EXPORTED_FROM_ABI tzdb_list& get_tzdb_list() {
  static tzdb_list __result{chrono::__make_tzdb()};
  return __result;
}

_LIBCPP_AVAILABILITY_TZDB _LIBCPP_EXPORTED_FROM_ABI const tzdb& reload_tzdb() {
  if (chrono::remote_version() == chrono::get_tzdb().version)
    return chrono::get_tzdb();

  return chrono::get_tzdb_list().__emplace_front(chrono::__make_tzdb());
}

_LIBCPP_NODISCARD_EXT _LIBCPP_AVAILABILITY_TZDB _LIBCPP_EXPORTED_FROM_ABI string remote_version() {
  filesystem::path __root = chrono::__libcpp_tzdb_directory();
  ifstream __tzdata{__root / "tzdata.zi"};
  return chrono::__parse_version(__tzdata);
}

} // namespace chrono

_LIBCPP_END_NAMESPACE_STD
