// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FILESYSTEM_FILESYSTEM_ERROR_H
#define _LIBCPP___FILESYSTEM_FILESYSTEM_ERROR_H

#include <__availability>
#include <__config>
#include <__filesystem/path.h>
#include <__memory/shared_ptr.h>
#include <__utility/forward.h>
#include <iosfwd>
#include <new>
#include <system_error>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

class _LIBCPP_AVAILABILITY_FILESYSTEM _LIBCPP_EXCEPTION_ABI filesystem_error : public system_error {
public:
  _LIBCPP_INLINE_VISIBILITY
  filesystem_error(const string& __what, error_code __ec)
      : system_error(__ec, __what),
        __storage_(make_shared<_Storage>(path(), path())) {
    __create_what(0);
  }

  _LIBCPP_INLINE_VISIBILITY
  filesystem_error(const string& __what, const path& __p1, error_code __ec)
      : system_error(__ec, __what),
        __storage_(make_shared<_Storage>(__p1, path())) {
    __create_what(1);
  }

  _LIBCPP_INLINE_VISIBILITY
  filesystem_error(const string& __what, const path& __p1, const path& __p2,
                   error_code __ec)
      : system_error(__ec, __what),
        __storage_(make_shared<_Storage>(__p1, __p2)) {
    __create_what(2);
  }

  _LIBCPP_INLINE_VISIBILITY
  const path& path1() const noexcept { return __storage_->__p1_; }

  _LIBCPP_INLINE_VISIBILITY
  const path& path2() const noexcept { return __storage_->__p2_; }

  filesystem_error(const filesystem_error&) = default;
  ~filesystem_error() override; // key function

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL
  const char* what() const noexcept override {
    return __storage_->__what_.c_str();
  }

  void __create_what(int __num_paths);

private:
  struct _LIBCPP_HIDDEN _Storage {
    _LIBCPP_INLINE_VISIBILITY
    _Storage(const path& __p1, const path& __p2) : __p1_(__p1), __p2_(__p2) {}

    path __p1_;
    path __p2_;
    string __what_;
  };
  shared_ptr<_Storage> __storage_;
};

// TODO(ldionne): We need to pop the pragma and push it again after
//                filesystem_error to work around PR41078.
_LIBCPP_AVAILABILITY_FILESYSTEM_PUSH

template <class... _Args>
_LIBCPP_NORETURN inline _LIBCPP_INLINE_VISIBILITY
#ifndef _LIBCPP_NO_EXCEPTIONS
void __throw_filesystem_error(_Args&&... __args) {
  throw filesystem_error(_VSTD::forward<_Args>(__args)...);
}
#else
void __throw_filesystem_error(_Args&&...) {
  _VSTD::abort();
}
#endif
_LIBCPP_AVAILABILITY_FILESYSTEM_POP

_LIBCPP_END_NAMESPACE_FILESYSTEM

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___FILESYSTEM_FILESYSTEM_ERROR_H
