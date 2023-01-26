// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMAT_FUNCTIONS
#define _LIBCPP___FORMAT_FORMAT_FUNCTIONS

// TODO FMT This is added to fix Apple back-deployment.
#include <version>
#if !defined(_LIBCPP_HAS_NO_INCOMPLETE_FORMAT)

#include <__algorithm/clamp.h>
#include <__availability>
#include <__concepts/convertible_to.h>
#include <__concepts/same_as.h>
#include <__config>
#include <__debug>
#include <__format/buffer.h>
#include <__format/format_arg.h>
#include <__format/format_arg_store.h>
#include <__format/format_args.h>
#include <__format/format_context.h>
#include <__format/format_error.h>
#include <__format/format_parse_context.h>
#include <__format/format_string.h>
#include <__format/format_to_n_result.h>
#include <__format/formatter.h>
#include <__format/formatter_bool.h>
#include <__format/formatter_char.h>
#include <__format/formatter_floating_point.h>
#include <__format/formatter_integer.h>
#include <__format/formatter_pointer.h>
#include <__format/formatter_string.h>
#include <__format/parser_std_format_spec.h>
#include <__iterator/back_insert_iterator.h>
#include <__iterator/incrementable_traits.h>
#include <__variant/monostate.h>
#include <array>
#include <string>
#include <string_view>

#ifndef _LIBCPP_HAS_NO_LOCALIZATION
#include <locale>
#endif

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Evaluate which templates should be external templates. This
// improves the efficiency of the header. However since the header is still
// under heavy development and not all classes are stable it makes no sense
// to do this optimization now.

using format_args = basic_format_args<format_context>;
#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
using wformat_args = basic_format_args<wformat_context>;
#endif

template <class _Context = format_context, class... _Args>
_LIBCPP_HIDE_FROM_ABI __format_arg_store<_Context, _Args...> make_format_args(_Args&&... __args) {
  return _VSTD::__format_arg_store<_Context, _Args...>(__args...);
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <class... _Args>
_LIBCPP_HIDE_FROM_ABI __format_arg_store<wformat_context, _Args...> make_wformat_args(_Args&&... __args) {
  return _VSTD::__format_arg_store<wformat_context, _Args...>(__args...);
}
#endif

namespace __format {

/// Helper class parse and handle argument.
///
/// When parsing a handle which is not enabled the code is ill-formed.
/// This helper uses the parser of the appropriate formatter for the stored type.
template <class _CharT>
class _LIBCPP_TEMPLATE_VIS __compile_time_handle {
public:
  _LIBCPP_HIDE_FROM_ABI
  constexpr void __parse(basic_format_parse_context<_CharT>& __parse_ctx) const { __parse_(__parse_ctx); }

  template <class _Tp>
  _LIBCPP_HIDE_FROM_ABI constexpr void __enable() {
    __parse_ = [](basic_format_parse_context<_CharT>& __parse_ctx) {
      formatter<_Tp, _CharT> __f;
      __parse_ctx.advance_to(__f.parse(__parse_ctx));
    };
  }

  // Before calling __parse the proper handler needs to be set with __enable.
  // The default handler isn't a core constant expression.
  _LIBCPP_HIDE_FROM_ABI constexpr __compile_time_handle()
      : __parse_([](basic_format_parse_context<_CharT>&) { std::__throw_format_error("Not a handle"); }) {}

private:
  void (*__parse_)(basic_format_parse_context<_CharT>&);
};

// Dummy format_context only providing the parts used during constant
// validation of the basic_format_string.
template <class _CharT>
struct _LIBCPP_TEMPLATE_VIS __compile_time_basic_format_context {
public:
  using char_type = _CharT;

  _LIBCPP_HIDE_FROM_ABI constexpr explicit __compile_time_basic_format_context(
      const __arg_t* __args, const __compile_time_handle<_CharT>* __handles, size_t __size)
      : __args_(__args), __handles_(__handles), __size_(__size) {}

  // During the compile-time validation nothing needs to be written.
  // Therefore all operations of this iterator are a NOP.
  struct iterator {
    _LIBCPP_HIDE_FROM_ABI constexpr iterator& operator=(_CharT) { return *this; }
    _LIBCPP_HIDE_FROM_ABI constexpr iterator& operator*() { return *this; }
    _LIBCPP_HIDE_FROM_ABI constexpr iterator operator++(int) { return *this; }
  };

  _LIBCPP_HIDE_FROM_ABI constexpr __arg_t arg(size_t __id) const {
    if (__id >= __size_)
      std::__throw_format_error("Argument index out of bounds");
    return __args_[__id];
  }

  _LIBCPP_HIDE_FROM_ABI constexpr const __compile_time_handle<_CharT>& __handle(size_t __id) const {
    if (__id >= __size_)
      std::__throw_format_error("Argument index out of bounds");
    return __handles_[__id];
  }

  _LIBCPP_HIDE_FROM_ABI constexpr iterator out() { return {}; }
  _LIBCPP_HIDE_FROM_ABI constexpr void advance_to(iterator) {}

private:
  const __arg_t* __args_;
  const __compile_time_handle<_CharT>* __handles_;
  size_t __size_;
};

_LIBCPP_HIDE_FROM_ABI
constexpr void __compile_time_validate_integral(__arg_t __type) {
  switch (__type) {
  case __arg_t::__int:
  case __arg_t::__long_long:
  case __arg_t::__i128:
  case __arg_t::__unsigned:
  case __arg_t::__unsigned_long_long:
  case __arg_t::__u128:
    return;

  default:
    std::__throw_format_error("Argument isn't an integral type");
  }
}

// _HasPrecision does the formatter have a precision?
template <class _CharT, class _Tp, bool _HasPrecision = false>
_LIBCPP_HIDE_FROM_ABI constexpr void
__compile_time_validate_argument(basic_format_parse_context<_CharT>& __parse_ctx,
                                 __compile_time_basic_format_context<_CharT>& __ctx) {
  formatter<_Tp, _CharT> __formatter;
  __parse_ctx.advance_to(__formatter.parse(__parse_ctx));
  // [format.string.std]/7
  // ... If the corresponding formatting argument is not of integral type, or
  // its value is negative for precision or non-positive for width, an
  // exception of type format_error is thrown.
  //
  // Validate whether the arguments are integrals.
  if (__formatter.__parser_.__width_as_arg_)
    __format::__compile_time_validate_integral(__ctx.arg(__formatter.__parser_.__width_));

  if constexpr (_HasPrecision)
    if (__formatter.__parser_.__precision_as_arg_)
      __format::__compile_time_validate_integral(__ctx.arg(__formatter.__parser_.__precision_));
}

// This function is not user facing, so it can directly use the non-standard types of the "variant".
template <class _CharT>
_LIBCPP_HIDE_FROM_ABI constexpr void __compile_time_visit_format_arg(basic_format_parse_context<_CharT>& __parse_ctx,
                                                                     __compile_time_basic_format_context<_CharT>& __ctx,
                                                                     __arg_t __type) {
  switch (__type) {
  case __arg_t::__none:
    std::__throw_format_error("Invalid argument");
  case __arg_t::__boolean:
    return __format::__compile_time_validate_argument<_CharT, bool>(__parse_ctx, __ctx);
  case __arg_t::__char_type:
    return __format::__compile_time_validate_argument<_CharT, _CharT>(__parse_ctx, __ctx);
  case __arg_t::__int:
    return __format::__compile_time_validate_argument<_CharT, int>(__parse_ctx, __ctx);
  case __arg_t::__long_long:
    return __format::__compile_time_validate_argument<_CharT, long long>(__parse_ctx, __ctx);
  case __arg_t::__i128:
#      ifndef _LIBCPP_HAS_NO_INT128
    return __format::__compile_time_validate_argument<_CharT, __int128_t>(__parse_ctx, __ctx);
#      else
    std::__throw_format_error("Invalid argument");
#      endif
    return;
  case __arg_t::__unsigned:
    return __format::__compile_time_validate_argument<_CharT, unsigned>(__parse_ctx, __ctx);
  case __arg_t::__unsigned_long_long:
    return __format::__compile_time_validate_argument<_CharT, unsigned long long>(__parse_ctx, __ctx);
  case __arg_t::__u128:
#      ifndef _LIBCPP_HAS_NO_INT128
    return __format::__compile_time_validate_argument<_CharT, __uint128_t>(__parse_ctx, __ctx);
#      else
    std::__throw_format_error("Invalid argument");
#      endif
    return;
  case __arg_t::__float:
    return __format::__compile_time_validate_argument<_CharT, float, true>(__parse_ctx, __ctx);
  case __arg_t::__double:
    return __format::__compile_time_validate_argument<_CharT, double, true>(__parse_ctx, __ctx);
  case __arg_t::__long_double:
    return __format::__compile_time_validate_argument<_CharT, long double, true>(__parse_ctx, __ctx);
  case __arg_t::__const_char_type_ptr:
    return __format::__compile_time_validate_argument<_CharT, const _CharT*, true>(__parse_ctx, __ctx);
  case __arg_t::__string_view:
    return __format::__compile_time_validate_argument<_CharT, basic_string_view<_CharT>, true>(__parse_ctx, __ctx);
  case __arg_t::__ptr:
    return __format::__compile_time_validate_argument<_CharT, const void*>(__parse_ctx, __ctx);
  case __arg_t::__handle:
    std::__throw_format_error("Handle should use __compile_time_validate_handle_argument");
  }
  std::__throw_format_error("Invalid argument");
}

template <class _CharT, class _ParseCtx, class _Ctx>
_LIBCPP_HIDE_FROM_ABI constexpr const _CharT*
__handle_replacement_field(const _CharT* __begin, const _CharT* __end,
                           _ParseCtx& __parse_ctx, _Ctx& __ctx) {
  __format::__parse_number_result __r = __format::__parse_arg_id(__begin, __end, __parse_ctx);

  bool __parse = *__r.__ptr == _CharT(':');
  switch (*__r.__ptr) {
  case _CharT(':'):
    // The arg-id has a format-specifier, advance the input to the format-spec.
    __parse_ctx.advance_to(__r.__ptr + 1);
    break;
  case _CharT('}'):
    // The arg-id has no format-specifier.
    __parse_ctx.advance_to(__r.__ptr);
    break;
  default:
    std::__throw_format_error("The replacement field arg-id should terminate at a ':' or '}'");
  }

  if constexpr (same_as<_Ctx, __compile_time_basic_format_context<_CharT>>) {
    __arg_t __type = __ctx.arg(__r.__value);
    if (__type == __arg_t::__handle)
      __ctx.__handle(__r.__value).__parse(__parse_ctx);
    else
        __format::__compile_time_visit_format_arg(__parse_ctx, __ctx, __type);
  } else
    _VSTD::__visit_format_arg(
        [&](auto __arg) {
          if constexpr (same_as<decltype(__arg), monostate>)
            std::__throw_format_error("Argument index out of bounds");
          else if constexpr (same_as<decltype(__arg), typename basic_format_arg<_Ctx>::handle>)
            __arg.format(__parse_ctx, __ctx);
          else {
            formatter<decltype(__arg), _CharT> __formatter;
            if (__parse)
              __parse_ctx.advance_to(__formatter.parse(__parse_ctx));
            __ctx.advance_to(__formatter.format(__arg, __ctx));
          }
        },
        __ctx.arg(__r.__value));

  __begin = __parse_ctx.begin();
  if (__begin == __end || *__begin != _CharT('}'))
    std::__throw_format_error("The replacement field misses a terminating '}'");

  return ++__begin;
}

template <class _ParseCtx, class _Ctx>
_LIBCPP_HIDE_FROM_ABI constexpr typename _Ctx::iterator
__vformat_to(_ParseCtx&& __parse_ctx, _Ctx&& __ctx) {
  using _CharT = typename _ParseCtx::char_type;
  static_assert(same_as<typename _Ctx::char_type, _CharT>);

  const _CharT* __begin = __parse_ctx.begin();
  const _CharT* __end = __parse_ctx.end();
  typename _Ctx::iterator __out_it = __ctx.out();
  while (__begin != __end) {
    switch (*__begin) {
    case _CharT('{'):
      ++__begin;
      if (__begin == __end)
        std::__throw_format_error("The format string terminates at a '{'");

      if (*__begin != _CharT('{')) [[likely]] {
        __ctx.advance_to(_VSTD::move(__out_it));
        __begin =
            __format::__handle_replacement_field(__begin, __end, __parse_ctx, __ctx);
        __out_it = __ctx.out();

        // The output is written and __begin points to the next character. So
        // start the next iteration.
        continue;
      }
      // The string is an escape character.
      break;

    case _CharT('}'):
      ++__begin;
      if (__begin == __end || *__begin != _CharT('}'))
        std::__throw_format_error("The format string contains an invalid escape sequence");

      break;
    }

    // Copy the character to the output verbatim.
    *__out_it++ = *__begin++;
  }
  return __out_it;
}

} // namespace __format

template <class _CharT, class... _Args>
struct _LIBCPP_TEMPLATE_VIS basic_format_string {
  template <class _Tp>
    requires convertible_to<const _Tp&, basic_string_view<_CharT>>
  consteval basic_format_string(const _Tp& __str) : __str_{__str} {
    __format::__vformat_to(basic_format_parse_context<_CharT>{__str_, sizeof...(_Args)},
                           _Context{__types_.data(), __handles_.data(), sizeof...(_Args)});
  }

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT constexpr basic_string_view<_CharT> get() const noexcept {
    return __str_;
  }

private:
  basic_string_view<_CharT> __str_;

  using _Context = __format::__compile_time_basic_format_context<_CharT>;

  static constexpr array<__format::__arg_t, sizeof...(_Args)> __types_{
      __format::__determine_arg_t<_Context, remove_cvref_t<_Args>>()...};

  // TODO FMT remove this work-around when the AIX ICE has been resolved.
#    if defined(_AIX) && defined(_LIBCPP_CLANG_VER) && _LIBCPP_CLANG_VER < 1400
  template <class _Tp>
  static constexpr __format::__compile_time_handle<_CharT> __get_handle() {
    __format::__compile_time_handle<_CharT> __handle;
    if (__format::__determine_arg_t<_Context, _Tp>() == __format::__arg_t::__handle)
      __handle.template __enable<_Tp>();

    return __handle;
  }

  static constexpr array<__format::__compile_time_handle<_CharT>, sizeof...(_Args)> __handles_{
      __get_handle<_Args>()...};
#    else
  static constexpr array<__format::__compile_time_handle<_CharT>, sizeof...(_Args)> __handles_{[] {
    using _Tp = remove_cvref_t<_Args>;
    __format::__compile_time_handle<_CharT> __handle;
    if (__format::__determine_arg_t<_Context, _Tp>() == __format::__arg_t::__handle)
      __handle.template __enable<_Tp>();

    return __handle;
  }()...};
#    endif
};

template <class... _Args>
using format_string = basic_format_string<char, type_identity_t<_Args>...>;

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <class... _Args>
using wformat_string = basic_format_string<wchar_t, type_identity_t<_Args>...>;
#endif

template <class _OutIt, class _CharT, class _FormatOutIt>
requires(output_iterator<_OutIt, const _CharT&>) _LIBCPP_HIDE_FROM_ABI _OutIt
    __vformat_to(
        _OutIt __out_it, basic_string_view<_CharT> __fmt,
        basic_format_args<basic_format_context<_FormatOutIt, _CharT>> __args) {
  if constexpr (same_as<_OutIt, _FormatOutIt>)
    return _VSTD::__format::__vformat_to(basic_format_parse_context{__fmt, __args.__size()},
                                         _VSTD::__format_context_create(_VSTD::move(__out_it), __args));
  else {
    __format::__format_buffer<_OutIt, _CharT> __buffer{_VSTD::move(__out_it)};
    _VSTD::__format::__vformat_to(basic_format_parse_context{__fmt, __args.__size()},
                                  _VSTD::__format_context_create(__buffer.__make_output_iterator(), __args));
    return _VSTD::move(__buffer).__out_it();
  }
}

// The function is _LIBCPP_ALWAYS_INLINE since the compiler is bad at inlining
// https://reviews.llvm.org/D110499#inline-1180704
// TODO FMT Evaluate whether we want to file a Clang bug report regarding this.
template <output_iterator<const char&> _OutIt>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT _OutIt
vformat_to(_OutIt __out_it, string_view __fmt, format_args __args) {
  return _VSTD::__vformat_to(_VSTD::move(__out_it), __fmt, __args);
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <output_iterator<const wchar_t&> _OutIt>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT _OutIt
vformat_to(_OutIt __out_it, wstring_view __fmt, wformat_args __args) {
  return _VSTD::__vformat_to(_VSTD::move(__out_it), __fmt, __args);
}
#endif

template <output_iterator<const char&> _OutIt, class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT _OutIt
format_to(_OutIt __out_it, format_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::vformat_to(_VSTD::move(__out_it), __fmt.get(),
                           _VSTD::make_format_args(__args...));
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <output_iterator<const wchar_t&> _OutIt, class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT _OutIt
format_to(_OutIt __out_it, wformat_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::vformat_to(_VSTD::move(__out_it), __fmt.get(),
                           _VSTD::make_wformat_args(__args...));
}
#endif

_LIBCPP_ALWAYS_INLINE inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT string
vformat(string_view __fmt, format_args __args) {
  string __res;
  _VSTD::vformat_to(_VSTD::back_inserter(__res), __fmt, __args);
  return __res;
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
_LIBCPP_ALWAYS_INLINE inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT wstring
vformat(wstring_view __fmt, wformat_args __args) {
  wstring __res;
  _VSTD::vformat_to(_VSTD::back_inserter(__res), __fmt, __args);
  return __res;
}
#endif

template <class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT string format(format_string<_Args...> __fmt,
                                                                                      _Args&&... __args) {
  return _VSTD::vformat(__fmt.get(), _VSTD::make_format_args(__args...));
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT wstring
format(wformat_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::vformat(__fmt.get(), _VSTD::make_wformat_args(__args...));
}
#endif

template <class _Context, class _OutIt, class _CharT>
_LIBCPP_HIDE_FROM_ABI format_to_n_result<_OutIt> __vformat_to_n(_OutIt __out_it, iter_difference_t<_OutIt> __n,
                                                                basic_string_view<_CharT> __fmt,
                                                                basic_format_args<_Context> __args) {
  __format::__format_to_n_buffer<_OutIt, _CharT> __buffer{_VSTD::move(__out_it), __n};
  _VSTD::__format::__vformat_to(basic_format_parse_context{__fmt, __args.__size()},
                                _VSTD::__format_context_create(__buffer.__make_output_iterator(), __args));
  return _VSTD::move(__buffer).__result();
}

template <output_iterator<const char&> _OutIt, class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT format_to_n_result<_OutIt>
format_to_n(_OutIt __out_it, iter_difference_t<_OutIt> __n, format_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::__vformat_to_n<format_context>(_VSTD::move(__out_it), __n, __fmt.get(), _VSTD::make_format_args(__args...));
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <output_iterator<const wchar_t&> _OutIt, class... _Args>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT format_to_n_result<_OutIt>
format_to_n(_OutIt __out_it, iter_difference_t<_OutIt> __n, wformat_string<_Args...> __fmt,
            _Args&&... __args) {
  return _VSTD::__vformat_to_n<wformat_context>(_VSTD::move(__out_it), __n, __fmt.get(), _VSTD::make_wformat_args(__args...));
}
#endif

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI size_t __vformatted_size(basic_string_view<_CharT> __fmt, auto __args) {
  __format::__formatted_size_buffer<_CharT> __buffer;
  _VSTD::__format::__vformat_to(basic_format_parse_context{__fmt, __args.__size()},
                                _VSTD::__format_context_create(__buffer.__make_output_iterator(), __args));
  return _VSTD::move(__buffer).__result();
}

template <class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT size_t
formatted_size(format_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::__vformatted_size(__fmt.get(), basic_format_args{_VSTD::make_format_args(__args...)});
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT size_t
formatted_size(wformat_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::__vformatted_size(__fmt.get(), basic_format_args{_VSTD::make_wformat_args(__args...)});
}
#endif

#ifndef _LIBCPP_HAS_NO_LOCALIZATION

template <class _OutIt, class _CharT, class _FormatOutIt>
requires(output_iterator<_OutIt, const _CharT&>) _LIBCPP_HIDE_FROM_ABI _OutIt
    __vformat_to(
        _OutIt __out_it, locale __loc, basic_string_view<_CharT> __fmt,
        basic_format_args<basic_format_context<_FormatOutIt, _CharT>> __args) {
  if constexpr (same_as<_OutIt, _FormatOutIt>)
    return _VSTD::__format::__vformat_to(
        basic_format_parse_context{__fmt, __args.__size()},
        _VSTD::__format_context_create(_VSTD::move(__out_it), __args, _VSTD::move(__loc)));
  else {
    __format::__format_buffer<_OutIt, _CharT> __buffer{_VSTD::move(__out_it)};
    _VSTD::__format::__vformat_to(
        basic_format_parse_context{__fmt, __args.__size()},
        _VSTD::__format_context_create(__buffer.__make_output_iterator(), __args, _VSTD::move(__loc)));
    return _VSTD::move(__buffer).__out_it();
  }
}

template <output_iterator<const char&> _OutIt>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT _OutIt vformat_to(
    _OutIt __out_it, locale __loc, string_view __fmt, format_args __args) {
  return _VSTD::__vformat_to(_VSTD::move(__out_it), _VSTD::move(__loc), __fmt,
                             __args);
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <output_iterator<const wchar_t&> _OutIt>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT _OutIt vformat_to(
    _OutIt __out_it, locale __loc, wstring_view __fmt, wformat_args __args) {
  return _VSTD::__vformat_to(_VSTD::move(__out_it), _VSTD::move(__loc), __fmt,
                             __args);
}
#endif

template <output_iterator<const char&> _OutIt, class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT _OutIt
format_to(_OutIt __out_it, locale __loc, format_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::vformat_to(_VSTD::move(__out_it), _VSTD::move(__loc), __fmt.get(),
                           _VSTD::make_format_args(__args...));
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <output_iterator<const wchar_t&> _OutIt, class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT _OutIt
format_to(_OutIt __out_it, locale __loc, wformat_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::vformat_to(_VSTD::move(__out_it), _VSTD::move(__loc), __fmt.get(),
                           _VSTD::make_wformat_args(__args...));
}
#endif

_LIBCPP_ALWAYS_INLINE inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT string
vformat(locale __loc, string_view __fmt, format_args __args) {
  string __res;
  _VSTD::vformat_to(_VSTD::back_inserter(__res), _VSTD::move(__loc), __fmt,
                    __args);
  return __res;
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
_LIBCPP_ALWAYS_INLINE inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT wstring
vformat(locale __loc, wstring_view __fmt, wformat_args __args) {
  wstring __res;
  _VSTD::vformat_to(_VSTD::back_inserter(__res), _VSTD::move(__loc), __fmt,
                    __args);
  return __res;
}
#endif

template <class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT string format(locale __loc,
                                                                                      format_string<_Args...> __fmt,
                                                                                      _Args&&... __args) {
  return _VSTD::vformat(_VSTD::move(__loc), __fmt.get(),
                        _VSTD::make_format_args(__args...));
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT wstring
format(locale __loc, wformat_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::vformat(_VSTD::move(__loc), __fmt.get(),
                        _VSTD::make_wformat_args(__args...));
}
#endif

template <class _Context, class _OutIt, class _CharT>
_LIBCPP_HIDE_FROM_ABI format_to_n_result<_OutIt> __vformat_to_n(_OutIt __out_it, iter_difference_t<_OutIt> __n,
                                                                locale __loc, basic_string_view<_CharT> __fmt,
                                                                basic_format_args<_Context> __args) {
  __format::__format_to_n_buffer<_OutIt, _CharT> __buffer{_VSTD::move(__out_it), __n};
  _VSTD::__format::__vformat_to(
      basic_format_parse_context{__fmt, __args.__size()},
      _VSTD::__format_context_create(__buffer.__make_output_iterator(), __args, _VSTD::move(__loc)));
  return _VSTD::move(__buffer).__result();
}

template <output_iterator<const char&> _OutIt, class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT format_to_n_result<_OutIt>
format_to_n(_OutIt __out_it, iter_difference_t<_OutIt> __n, locale __loc, format_string<_Args...> __fmt,
            _Args&&... __args) {
  return _VSTD::__vformat_to_n<format_context>(_VSTD::move(__out_it), __n, _VSTD::move(__loc), __fmt.get(),
                                               _VSTD::make_format_args(__args...));
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <output_iterator<const wchar_t&> _OutIt, class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT format_to_n_result<_OutIt>
format_to_n(_OutIt __out_it, iter_difference_t<_OutIt> __n, locale __loc, wformat_string<_Args...> __fmt,
            _Args&&... __args) {
  return _VSTD::__vformat_to_n<wformat_context>(_VSTD::move(__out_it), __n, _VSTD::move(__loc), __fmt.get(),
                                                _VSTD::make_wformat_args(__args...));
}
#endif

template <class _CharT>
_LIBCPP_HIDE_FROM_ABI size_t __vformatted_size(locale __loc, basic_string_view<_CharT> __fmt, auto __args) {
  __format::__formatted_size_buffer<_CharT> __buffer;
  _VSTD::__format::__vformat_to(
      basic_format_parse_context{__fmt, __args.__size()},
      _VSTD::__format_context_create(__buffer.__make_output_iterator(), __args, _VSTD::move(__loc)));
  return _VSTD::move(__buffer).__result();
}

template <class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT size_t
formatted_size(locale __loc, format_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::__vformatted_size(_VSTD::move(__loc), __fmt.get(), basic_format_args{_VSTD::make_format_args(__args...)});
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <class... _Args>
_LIBCPP_ALWAYS_INLINE _LIBCPP_HIDE_FROM_ABI _LIBCPP_AVAILABILITY_FORMAT size_t
formatted_size(locale __loc, wformat_string<_Args...> __fmt, _Args&&... __args) {
  return _VSTD::__vformatted_size(_VSTD::move(__loc), __fmt.get(), basic_format_args{_VSTD::make_wformat_args(__args...)});
}
#endif

#endif // _LIBCPP_HAS_NO_LOCALIZATION


#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // !defined(_LIBCPP_HAS_NO_INCOMPLETE_FORMAT)

#endif // _LIBCPP___FORMAT_FORMAT_FUNCTIONS
