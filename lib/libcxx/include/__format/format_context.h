// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMAT_CONTEXT_H
#define _LIBCPP___FORMAT_FORMAT_CONTEXT_H

#include <__availability>
#include <__config>
#include <__format/format_args.h>
#include <__format/format_fwd.h>
#include <__iterator/back_insert_iterator.h>
#include <__iterator/concepts.h>
#include <concepts>

#ifndef _LIBCPP_HAS_NO_LOCALIZATION
#include <locale>
#include <optional>
#endif

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Remove this once we require compilers with proper C++20 support.
// If the compiler has no concepts support, the format header will be disabled.
// Without concepts support enable_if needs to be used and that too much effort
// to support compilers with partial C++20 support.
#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

template <class _OutIt, class _CharT>
requires output_iterator<_OutIt, const _CharT&>
class _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT basic_format_context;

#ifndef _LIBCPP_HAS_NO_LOCALIZATION
/**
 * Helper to create a basic_format_context.
 *
 * This is needed since the constructor is private.
 */
template <class _OutIt, class _CharT>
_LIBCPP_HIDE_FROM_ABI basic_format_context<_OutIt, _CharT>
__format_context_create(
    _OutIt __out_it,
    basic_format_args<basic_format_context<_OutIt, _CharT>> __args,
    optional<_VSTD::locale>&& __loc = nullopt) {
  return _VSTD::basic_format_context(_VSTD::move(__out_it), __args,
                                     _VSTD::move(__loc));
}
#else
template <class _OutIt, class _CharT>
_LIBCPP_HIDE_FROM_ABI basic_format_context<_OutIt, _CharT>
__format_context_create(
    _OutIt __out_it,
    basic_format_args<basic_format_context<_OutIt, _CharT>> __args) {
  return _VSTD::basic_format_context(_VSTD::move(__out_it), __args);
}
#endif

// TODO FMT Implement [format.context]/4
// [Note 1: For a given type charT, implementations are encouraged to provide a
// single instantiation of basic_format_context for appending to
// basic_string<charT>, vector<charT>, or any other container with contiguous
// storage by wrapping those in temporary objects with a uniform interface
// (such as a span<charT>) and polymorphic reallocation. - end note]

using format_context = basic_format_context<back_insert_iterator<string>, char>;
#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
using wformat_context = basic_format_context<back_insert_iterator<wstring>, wchar_t>;
#endif

template <class _OutIt, class _CharT>
requires output_iterator<_OutIt, const _CharT&>
class
    // clang-format off
    _LIBCPP_TEMPLATE_VIS
    _LIBCPP_AVAILABILITY_FORMAT
    _LIBCPP_PREFERRED_NAME(format_context)
    _LIBCPP_IF_WIDE_CHARACTERS(_LIBCPP_PREFERRED_NAME(wformat_context))
    // clang-format on
    basic_format_context {
public:
  using iterator = _OutIt;
  using char_type = _CharT;
  template <class _Tp>
  using formatter_type = formatter<_Tp, _CharT>;

  basic_format_context(const basic_format_context&) = delete;
  basic_format_context& operator=(const basic_format_context&) = delete;

  _LIBCPP_HIDE_FROM_ABI basic_format_arg<basic_format_context>
  arg(size_t __id) const {
    return __args_.get(__id);
  }
#ifndef _LIBCPP_HAS_NO_LOCALIZATION
  _LIBCPP_HIDE_FROM_ABI _VSTD::locale locale() {
    if (!__loc_)
      __loc_ = _VSTD::locale{};
    return *__loc_;
  }
#endif
  _LIBCPP_HIDE_FROM_ABI iterator out() { return __out_it_; }
  _LIBCPP_HIDE_FROM_ABI void advance_to(iterator __it) { __out_it_ = __it; }

private:
  iterator __out_it_;
  basic_format_args<basic_format_context> __args_;
#ifndef _LIBCPP_HAS_NO_LOCALIZATION

  // The Standard doesn't specify how the locale is stored.
  // [format.context]/6
  // std::locale locale();
  //   Returns: The locale passed to the formatting function if the latter
  //   takes one, and std::locale() otherwise.
  // This is done by storing the locale of the constructor in this optional. If
  // locale() is called and the optional has no value the value will be created.
  // This allows the implementation to lazily create the locale.
  // TODO FMT Validate whether lazy creation is the best solution.
  optional<_VSTD::locale> __loc_;

  template <class __OutIt, class __CharT>
  friend _LIBCPP_HIDE_FROM_ABI basic_format_context<__OutIt, __CharT>
  __format_context_create(__OutIt, basic_format_args<basic_format_context<__OutIt, __CharT>>,
                          optional<_VSTD::locale>&&);

  // Note: the Standard doesn't specify the required constructors.
  _LIBCPP_HIDE_FROM_ABI
  explicit basic_format_context(_OutIt __out_it,
                                basic_format_args<basic_format_context> __args,
                                optional<_VSTD::locale>&& __loc)
      : __out_it_(_VSTD::move(__out_it)), __args_(__args),
        __loc_(_VSTD::move(__loc)) {}
#else
  template <class __OutIt, class __CharT>
  friend _LIBCPP_HIDE_FROM_ABI basic_format_context<__OutIt, __CharT>
      __format_context_create(__OutIt, basic_format_args<basic_format_context<__OutIt, __CharT>>);

  _LIBCPP_HIDE_FROM_ABI
  explicit basic_format_context(_OutIt __out_it,
                                basic_format_args<basic_format_context> __args)
      : __out_it_(_VSTD::move(__out_it)), __args_(__args) {}
#endif
};

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FORMAT_FORMAT_CONTEXT_H
