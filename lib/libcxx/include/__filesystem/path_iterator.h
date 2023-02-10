// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FILESYSTEM_PATH_ITERATOR_H
#define _LIBCPP___FILESYSTEM_PATH_ITERATOR_H

#include <__assert>
#include <__availability>
#include <__config>
#include <__filesystem/path.h>
#include <__iterator/iterator_traits.h>
#include <cstddef>
#include <string>
#include <string_view>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

_LIBCPP_AVAILABILITY_FILESYSTEM_PUSH

class _LIBCPP_TYPE_VIS path::iterator {
public:
  enum _ParserState : unsigned char {
    _Singular,
    _BeforeBegin,
    _InRootName,
    _InRootDir,
    _InFilenames,
    _InTrailingSep,
    _AtEnd
  };

public:
  typedef input_iterator_tag iterator_category;
  typedef bidirectional_iterator_tag iterator_concept;

  typedef path value_type;
  typedef ptrdiff_t difference_type;
  typedef const path* pointer;
  typedef path reference;

public:
  _LIBCPP_INLINE_VISIBILITY
  iterator()
      : __stashed_elem_(), __path_ptr_(nullptr), __entry_(),
        __state_(_Singular) {}

  iterator(const iterator&) = default;
  ~iterator() = default;

  iterator& operator=(const iterator&) = default;

  _LIBCPP_INLINE_VISIBILITY
  reference operator*() const { return __stashed_elem_; }

  _LIBCPP_INLINE_VISIBILITY
  pointer operator->() const { return &__stashed_elem_; }

  _LIBCPP_INLINE_VISIBILITY
  iterator& operator++() {
    _LIBCPP_ASSERT(__state_ != _Singular,
                   "attempting to increment a singular iterator");
    _LIBCPP_ASSERT(__state_ != _AtEnd,
                   "attempting to increment the end iterator");
    return __increment();
  }

  _LIBCPP_INLINE_VISIBILITY
  iterator operator++(int) {
    iterator __it(*this);
    this->operator++();
    return __it;
  }

  _LIBCPP_INLINE_VISIBILITY
  iterator& operator--() {
    _LIBCPP_ASSERT(__state_ != _Singular,
                   "attempting to decrement a singular iterator");
    _LIBCPP_ASSERT(__entry_.data() != __path_ptr_->native().data(),
                   "attempting to decrement the begin iterator");
    return __decrement();
  }

  _LIBCPP_INLINE_VISIBILITY
  iterator operator--(int) {
    iterator __it(*this);
    this->operator--();
    return __it;
  }

private:
  friend class path;

  inline _LIBCPP_INLINE_VISIBILITY friend bool operator==(const iterator&,
                                                          const iterator&);

  iterator& __increment();
  iterator& __decrement();

  path __stashed_elem_;
  const path* __path_ptr_;
  path::__string_view __entry_;
  _ParserState __state_;
};

inline _LIBCPP_INLINE_VISIBILITY bool operator==(const path::iterator& __lhs,
                                                 const path::iterator& __rhs) {
  return __lhs.__path_ptr_ == __rhs.__path_ptr_ &&
         __lhs.__entry_.data() == __rhs.__entry_.data();
}

inline _LIBCPP_INLINE_VISIBILITY bool operator!=(const path::iterator& __lhs,
                                                 const path::iterator& __rhs) {
  return !(__lhs == __rhs);
}

_LIBCPP_AVAILABILITY_FILESYSTEM_POP

_LIBCPP_END_NAMESPACE_FILESYSTEM

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___FILESYSTEM_PATH_ITERATOR_H
