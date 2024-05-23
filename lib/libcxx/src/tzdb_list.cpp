//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// For information see https://libcxx.llvm.org/DesignDocs/TimeZone.html

#include <chrono>

#include <__mutex/unique_lock.h>
#include <forward_list>

// When threads are not available the locking is not required.
#ifndef _LIBCPP_HAS_NO_THREADS
#  include <shared_mutex>
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

namespace chrono {

//===----------------------------------------------------------------------===//
//                          Private API
//===----------------------------------------------------------------------===//

class tzdb_list::__impl {
public:
  explicit __impl(tzdb&& __tzdb) { __tzdb_.push_front(std::move(__tzdb)); }

  using const_iterator = tzdb_list::const_iterator;

  const tzdb& front() const noexcept {
#ifndef _LIBCPP_HAS_NO_THREADS
    shared_lock __lock{__mutex_};
#endif
    return __tzdb_.front();
  }

  const_iterator erase_after(const_iterator __p) {
#ifndef _LIBCPP_HAS_NO_THREADS
    unique_lock __lock{__mutex_};
#endif
    return __tzdb_.erase_after(__p);
  }

  tzdb& __emplace_front(tzdb&& __tzdb) {
#ifndef _LIBCPP_HAS_NO_THREADS
    unique_lock __lock{__mutex_};
#endif
    return __tzdb_.emplace_front(std::move(__tzdb));
  }

  const_iterator begin() const noexcept {
#ifndef _LIBCPP_HAS_NO_THREADS
    shared_lock __lock{__mutex_};
#endif
    return __tzdb_.begin();
  }
  const_iterator end() const noexcept {
    //  forward_list<T>::end does not access the list, so no need to take a lock.
    return __tzdb_.end();
  }

  const_iterator cbegin() const noexcept { return begin(); }
  const_iterator cend() const noexcept { return end(); }

private:
#ifndef _LIBCPP_HAS_NO_THREADS
  mutable shared_mutex __mutex_;
#endif
  forward_list<tzdb> __tzdb_;
};

//===----------------------------------------------------------------------===//
//                           Public API
//===----------------------------------------------------------------------===//

_LIBCPP_EXPORTED_FROM_ABI tzdb_list::tzdb_list(tzdb&& __tzdb) : __impl_{new __impl(std::move(__tzdb))} {}

_LIBCPP_EXPORTED_FROM_ABI tzdb_list::~tzdb_list() { delete __impl_; }

_LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI const tzdb& tzdb_list::front() const noexcept {
  return __impl_->front();
}

_LIBCPP_EXPORTED_FROM_ABI tzdb_list::const_iterator tzdb_list::erase_after(const_iterator __p) {
  return __impl_->erase_after(__p);
}

_LIBCPP_EXPORTED_FROM_ABI tzdb& tzdb_list::__emplace_front(tzdb&& __tzdb) {
  return __impl_->__emplace_front(std::move(__tzdb));
}

_LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI tzdb_list::const_iterator tzdb_list::begin() const noexcept {
  return __impl_->begin();
}
_LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI tzdb_list::const_iterator tzdb_list::end() const noexcept {
  return __impl_->end();
}

_LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI tzdb_list::const_iterator tzdb_list::cbegin() const noexcept {
  return __impl_->cbegin();
}
_LIBCPP_NODISCARD_EXT _LIBCPP_EXPORTED_FROM_ABI tzdb_list::const_iterator tzdb_list::cend() const noexcept {
  return __impl_->cend();
}

} // namespace chrono

_LIBCPP_END_NAMESPACE_STD
