// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FILESYSTEM_RECURSIVE_DIRECTORY_ITERATOR_H
#define _LIBCPP___FILESYSTEM_RECURSIVE_DIRECTORY_ITERATOR_H

#include <__availability>
#include <__config>
#include <__filesystem/directory_entry.h>
#include <__filesystem/directory_options.h>
#include <__filesystem/path.h>
#include <__iterator/default_sentinel.h>
#include <__iterator/iterator_traits.h>
#include <__memory/shared_ptr.h>
#include <__ranges/enable_borrowed_range.h>
#include <__ranges/enable_view.h>
#include <__system_error/error_code.h>
#include <__utility/move.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if !defined(_LIBCPP_CXX03_LANG) && !defined(_LIBCPP_HAS_NO_FILESYSTEM)

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

_LIBCPP_AVAILABILITY_FILESYSTEM_LIBRARY_PUSH

class recursive_directory_iterator {
public:
  using value_type = directory_entry;
  using difference_type = ptrdiff_t;
  using pointer = directory_entry const*;
  using reference = directory_entry const&;
  using iterator_category = input_iterator_tag;

public:
  // constructors and destructor
  _LIBCPP_INLINE_VISIBILITY
  recursive_directory_iterator() noexcept : __rec_(false) {}

  _LIBCPP_INLINE_VISIBILITY
  explicit recursive_directory_iterator(
      const path& __p, directory_options __xoptions = directory_options::none)
      : recursive_directory_iterator(__p, __xoptions, nullptr) {}

  _LIBCPP_INLINE_VISIBILITY
  recursive_directory_iterator(const path& __p, directory_options __xoptions,
                               error_code& __ec)
      : recursive_directory_iterator(__p, __xoptions, &__ec) {}

  _LIBCPP_INLINE_VISIBILITY
  recursive_directory_iterator(const path& __p, error_code& __ec)
      : recursive_directory_iterator(__p, directory_options::none, &__ec) {}

  _LIBCPP_HIDE_FROM_ABI recursive_directory_iterator(const recursive_directory_iterator&) = default;
  _LIBCPP_HIDE_FROM_ABI recursive_directory_iterator(recursive_directory_iterator&&) = default;

  _LIBCPP_HIDE_FROM_ABI recursive_directory_iterator&
  operator=(const recursive_directory_iterator&) = default;

  _LIBCPP_INLINE_VISIBILITY
  recursive_directory_iterator&
  operator=(recursive_directory_iterator&& __o) noexcept {
    // non-default implementation provided to support self-move assign.
    if (this != &__o) {
      __imp_ = _VSTD::move(__o.__imp_);
      __rec_ = __o.__rec_;
    }
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI ~recursive_directory_iterator() = default;

  _LIBCPP_INLINE_VISIBILITY
  const directory_entry& operator*() const { return __dereference(); }

  _LIBCPP_INLINE_VISIBILITY
  const directory_entry* operator->() const { return &__dereference(); }

  _LIBCPP_HIDE_FROM_ABI recursive_directory_iterator& operator++() { return __increment(); }

  _LIBCPP_INLINE_VISIBILITY
  __dir_element_proxy operator++(int) {
    __dir_element_proxy __p(**this);
    __increment();
    return __p;
  }

  _LIBCPP_INLINE_VISIBILITY
  recursive_directory_iterator& increment(error_code& __ec) {
    return __increment(&__ec);
  }

  _LIBCPP_EXPORTED_FROM_ABI directory_options options() const;
  _LIBCPP_EXPORTED_FROM_ABI int depth() const;

  _LIBCPP_INLINE_VISIBILITY
  void pop() { __pop(); }

  _LIBCPP_INLINE_VISIBILITY
  void pop(error_code& __ec) { __pop(&__ec); }

  _LIBCPP_INLINE_VISIBILITY
  bool recursion_pending() const { return __rec_; }

  _LIBCPP_INLINE_VISIBILITY
  void disable_recursion_pending() { __rec_ = false; }

#  if _LIBCPP_STD_VER >= 20

  _LIBCPP_HIDE_FROM_ABI bool operator==(default_sentinel_t) const noexcept {
    return *this == recursive_directory_iterator();
  }

#  endif

private:
  _LIBCPP_EXPORTED_FROM_ABI recursive_directory_iterator(const path& __p, directory_options __opt, error_code* __ec);
  _LIBCPP_EXPORTED_FROM_ABI const directory_entry& __dereference() const;
  _LIBCPP_EXPORTED_FROM_ABI bool __try_recursion(error_code* __ec);
  _LIBCPP_EXPORTED_FROM_ABI void __advance(error_code* __ec = nullptr);
  _LIBCPP_EXPORTED_FROM_ABI recursive_directory_iterator& __increment(error_code* __ec = nullptr);
  _LIBCPP_EXPORTED_FROM_ABI void __pop(error_code* __ec = nullptr);

  inline _LIBCPP_INLINE_VISIBILITY friend bool
  operator==(const recursive_directory_iterator&,
             const recursive_directory_iterator&) noexcept;

  struct _LIBCPP_HIDDEN __shared_imp;
  shared_ptr<__shared_imp> __imp_;
  bool __rec_;
}; // class recursive_directory_iterator

inline _LIBCPP_INLINE_VISIBILITY bool
operator==(const recursive_directory_iterator& __lhs,
           const recursive_directory_iterator& __rhs) noexcept {
  return __lhs.__imp_ == __rhs.__imp_;
}

_LIBCPP_INLINE_VISIBILITY
inline bool operator!=(const recursive_directory_iterator& __lhs,
                       const recursive_directory_iterator& __rhs) noexcept {
  return !(__lhs == __rhs);
}
// enable recursive_directory_iterator range-based for statements
inline _LIBCPP_INLINE_VISIBILITY recursive_directory_iterator
begin(recursive_directory_iterator __iter) noexcept {
  return __iter;
}

inline _LIBCPP_INLINE_VISIBILITY recursive_directory_iterator
end(recursive_directory_iterator) noexcept {
  return recursive_directory_iterator();
}

_LIBCPP_AVAILABILITY_FILESYSTEM_LIBRARY_POP

_LIBCPP_END_NAMESPACE_FILESYSTEM

#if _LIBCPP_STD_VER >= 20

template <>
_LIBCPP_AVAILABILITY_FILESYSTEM_LIBRARY
inline constexpr bool _VSTD::ranges::enable_borrowed_range<_VSTD_FS::recursive_directory_iterator> = true;

template <>
_LIBCPP_AVAILABILITY_FILESYSTEM_LIBRARY
inline constexpr bool _VSTD::ranges::enable_view<_VSTD_FS::recursive_directory_iterator> = true;

#endif // _LIBCPP_STD_VER >= 20

#endif // !defined(_LIBCPP_CXX03_LANG) && !defined(_LIBCPP_HAS_NO_FILESYSTEM)

#endif // _LIBCPP___FILESYSTEM_RECURSIVE_DIRECTORY_ITERATOR_H
