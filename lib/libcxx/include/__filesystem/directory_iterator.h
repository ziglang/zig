// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FILESYSTEM_DIRECTORY_ITERATOR_H
#define _LIBCPP___FILESYSTEM_DIRECTORY_ITERATOR_H

#include <__assert>
#include <__availability>
#include <__config>
#include <__filesystem/directory_entry.h>
#include <__filesystem/directory_options.h>
#include <__filesystem/path.h>
#include <__iterator/iterator_traits.h>
#include <__memory/shared_ptr.h>
#include <__ranges/enable_borrowed_range.h>
#include <__ranges/enable_view.h>
#include <cstddef>
#include <system_error>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

_LIBCPP_AVAILABILITY_FILESYSTEM_PUSH

class _LIBCPP_HIDDEN __dir_stream;
class directory_iterator {
public:
  typedef directory_entry value_type;
  typedef ptrdiff_t difference_type;
  typedef value_type const* pointer;
  typedef value_type const& reference;
  typedef input_iterator_tag iterator_category;

public:
  //ctor & dtor
  _LIBCPP_HIDE_FROM_ABI
  directory_iterator() noexcept {}

  _LIBCPP_HIDE_FROM_ABI
  explicit directory_iterator(const path& __p)
      : directory_iterator(__p, nullptr) {}

  _LIBCPP_HIDE_FROM_ABI
  directory_iterator(const path& __p, directory_options __opts)
      : directory_iterator(__p, nullptr, __opts) {}

  _LIBCPP_HIDE_FROM_ABI
  directory_iterator(const path& __p, error_code& __ec)
      : directory_iterator(__p, &__ec) {}

  _LIBCPP_HIDE_FROM_ABI
  directory_iterator(const path& __p, directory_options __opts,
                     error_code& __ec)
      : directory_iterator(__p, &__ec, __opts) {}

  _LIBCPP_HIDE_FROM_ABI directory_iterator(const directory_iterator&) = default;
  _LIBCPP_HIDE_FROM_ABI directory_iterator(directory_iterator&&) = default;
  _LIBCPP_HIDE_FROM_ABI directory_iterator& operator=(const directory_iterator&) = default;

  _LIBCPP_HIDE_FROM_ABI
  directory_iterator& operator=(directory_iterator&& __o) noexcept {
    // non-default implementation provided to support self-move assign.
    if (this != &__o) {
      __imp_ = _VSTD::move(__o.__imp_);
    }
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI ~directory_iterator() = default;

  _LIBCPP_HIDE_FROM_ABI
  const directory_entry& operator*() const {
    _LIBCPP_ASSERT(__imp_, "The end iterator cannot be dereferenced");
    return __dereference();
  }

  _LIBCPP_HIDE_FROM_ABI
  const directory_entry* operator->() const { return &**this; }

  _LIBCPP_HIDE_FROM_ABI
  directory_iterator& operator++() { return __increment(); }

  _LIBCPP_HIDE_FROM_ABI
  __dir_element_proxy operator++(int) {
    __dir_element_proxy __p(**this);
    __increment();
    return __p;
  }

  _LIBCPP_HIDE_FROM_ABI
  directory_iterator& increment(error_code& __ec) { return __increment(&__ec); }

private:
  inline _LIBCPP_HIDE_FROM_ABI friend bool
  operator==(const directory_iterator& __lhs,
             const directory_iterator& __rhs) noexcept;

  // construct the dir_stream
  _LIBCPP_FUNC_VIS
  directory_iterator(const path&, error_code*,
                     directory_options = directory_options::none);

  _LIBCPP_FUNC_VIS
  directory_iterator& __increment(error_code* __ec = nullptr);

  _LIBCPP_FUNC_VIS
  const directory_entry& __dereference() const;

private:
  shared_ptr<__dir_stream> __imp_;
};

inline _LIBCPP_HIDE_FROM_ABI bool
operator==(const directory_iterator& __lhs,
           const directory_iterator& __rhs) noexcept {
  return __lhs.__imp_ == __rhs.__imp_;
}

inline _LIBCPP_HIDE_FROM_ABI bool
operator!=(const directory_iterator& __lhs,
           const directory_iterator& __rhs) noexcept {
  return !(__lhs == __rhs);
}

// enable directory_iterator range-based for statements
inline _LIBCPP_HIDE_FROM_ABI directory_iterator
begin(directory_iterator __iter) noexcept {
  return __iter;
}

inline _LIBCPP_HIDE_FROM_ABI directory_iterator
end(directory_iterator) noexcept {
  return directory_iterator();
}

_LIBCPP_AVAILABILITY_FILESYSTEM_POP

_LIBCPP_END_NAMESPACE_FILESYSTEM

#if _LIBCPP_STD_VER > 17

template <>
_LIBCPP_AVAILABILITY_FILESYSTEM
inline constexpr bool _VSTD::ranges::enable_borrowed_range<_VSTD_FS::directory_iterator> = true;

template <>
_LIBCPP_AVAILABILITY_FILESYSTEM
inline constexpr bool _VSTD::ranges::enable_view<_VSTD_FS::directory_iterator> = true;

#endif // _LIBCPP_STD_VER > 17

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___FILESYSTEM_DIRECTORY_ITERATOR_H
