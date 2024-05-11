// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// For information see https://libcxx.llvm.org/DesignDocs/TimeZone.html

#ifndef _LIBCPP___CHRONO_TZDB_LIST_H
#define _LIBCPP___CHRONO_TZDB_LIST_H

#include <version>
// Enable the contents of the header only when libc++ was built with experimental features enabled.
#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_TZDB)

#  include <__availability>
#  include <__chrono/tzdb.h>
#  include <forward_list>
#  include <string_view>

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

_LIBCPP_BEGIN_NAMESPACE_STD

#  if _LIBCPP_STD_VER >= 20 && !defined(_LIBCPP_HAS_NO_TIME_ZONE_DATABASE) && !defined(_LIBCPP_HAS_NO_FILESYSTEM) &&   \
      !defined(_LIBCPP_HAS_NO_LOCALIZATION)

namespace chrono {

class _LIBCPP_AVAILABILITY_TZDB tzdb_list {
public:
  _LIBCPP_EXPORTED_FROM_ABI explicit tzdb_list(tzdb&& __tzdb);
  _LIBCPP_EXPORTED_FROM_ABI ~tzdb_list();

  tzdb_list(const tzdb_list&)            = delete;
  tzdb_list& operator=(const tzdb_list&) = delete;

  using const_iterator = forward_list<tzdb>::const_iterator;

  _LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI const tzdb& front() const noexcept;

  _LIBCPP_EXPORTED_FROM_ABI const_iterator erase_after(const_iterator __p);

  _LIBCPP_EXPORTED_FROM_ABI tzdb& __emplace_front(tzdb&& __tzdb);

  _LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI const_iterator begin() const noexcept;
  _LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI const_iterator end() const noexcept;

  _LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI const_iterator cbegin() const noexcept;
  _LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI const_iterator cend() const noexcept;

private:
  class __impl;
  __impl* __impl_;
};

_LIBCPP_NODISCARD_EXT _LIBCPP_AVAILABILITY_TZDB _LIBCPP_EXPORTED_FROM_ABI tzdb_list& get_tzdb_list();

_LIBCPP_NODISCARD_EXT _LIBCPP_AVAILABILITY_TZDB _LIBCPP_HIDE_FROM_ABI inline const tzdb& get_tzdb() {
  return get_tzdb_list().front();
}

_LIBCPP_AVAILABILITY_TZDB _LIBCPP_EXPORTED_FROM_ABI const tzdb& reload_tzdb();

_LIBCPP_NODISCARD_EXT _LIBCPP_AVAILABILITY_TZDB _LIBCPP_EXPORTED_FROM_ABI string remote_version();

} // namespace chrono

#  endif // _LIBCPP_STD_VER >= 20 && !defined(_LIBCPP_HAS_NO_TIME_ZONE_DATABASE) && !defined(_LIBCPP_HAS_NO_FILESYSTEM)
         // && !defined(_LIBCPP_HAS_NO_LOCALIZATION)

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_TZDB)

#endif // _LIBCPP___CHRONO_TZDB_LIST_H
