//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___LOCALE_DIR_WSTRING_CONVERT_H
#define _LIBCPP___LOCALE_DIR_WSTRING_CONVERT_H

#include <__config>
#include <__locale>
#include <__memory/allocator.h>
#include <string>

#if _LIBCPP_HAS_LOCALIZATION

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

#  if _LIBCPP_STD_VER < 26 || defined(_LIBCPP_ENABLE_CXX26_REMOVED_WSTRING_CONVERT)

_LIBCPP_PUSH_MACROS
#    include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Codecvt,
          class _Elem      = wchar_t,
          class _WideAlloc = allocator<_Elem>,
          class _ByteAlloc = allocator<char> >
class _LIBCPP_DEPRECATED_IN_CXX17 wstring_convert {
public:
  typedef basic_string<char, char_traits<char>, _ByteAlloc> byte_string;
  typedef basic_string<_Elem, char_traits<_Elem>, _WideAlloc> wide_string;
  typedef typename _Codecvt::state_type state_type;
  typedef typename wide_string::traits_type::int_type int_type;

private:
  byte_string __byte_err_string_;
  wide_string __wide_err_string_;
  _Codecvt* __cvtptr_;
  state_type __cvtstate_;
  size_t __cvtcount_;

public:
#    ifndef _LIBCPP_CXX03_LANG
  _LIBCPP_HIDE_FROM_ABI wstring_convert() : wstring_convert(new _Codecvt) {}
  _LIBCPP_HIDE_FROM_ABI explicit wstring_convert(_Codecvt* __pcvt);
#    else
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_EXPLICIT_SINCE_CXX14 wstring_convert(_Codecvt* __pcvt = new _Codecvt);
#    endif

  _LIBCPP_HIDE_FROM_ABI wstring_convert(_Codecvt* __pcvt, state_type __state);
  _LIBCPP_EXPLICIT_SINCE_CXX14 _LIBCPP_HIDE_FROM_ABI
  wstring_convert(const byte_string& __byte_err, const wide_string& __wide_err = wide_string());
#    ifndef _LIBCPP_CXX03_LANG
  _LIBCPP_HIDE_FROM_ABI wstring_convert(wstring_convert&& __wc);
#    endif
  _LIBCPP_HIDE_FROM_ABI ~wstring_convert();

  wstring_convert(const wstring_convert& __wc)            = delete;
  wstring_convert& operator=(const wstring_convert& __wc) = delete;

  _LIBCPP_HIDE_FROM_ABI wide_string from_bytes(char __byte) { return from_bytes(&__byte, &__byte + 1); }
  _LIBCPP_HIDE_FROM_ABI wide_string from_bytes(const char* __ptr) {
    return from_bytes(__ptr, __ptr + char_traits<char>::length(__ptr));
  }
  _LIBCPP_HIDE_FROM_ABI wide_string from_bytes(const byte_string& __str) {
    return from_bytes(__str.data(), __str.data() + __str.size());
  }
  _LIBCPP_HIDE_FROM_ABI wide_string from_bytes(const char* __first, const char* __last);

  _LIBCPP_HIDE_FROM_ABI byte_string to_bytes(_Elem __wchar) {
    return to_bytes(std::addressof(__wchar), std::addressof(__wchar) + 1);
  }
  _LIBCPP_HIDE_FROM_ABI byte_string to_bytes(const _Elem* __wptr) {
    return to_bytes(__wptr, __wptr + char_traits<_Elem>::length(__wptr));
  }
  _LIBCPP_HIDE_FROM_ABI byte_string to_bytes(const wide_string& __wstr) {
    return to_bytes(__wstr.data(), __wstr.data() + __wstr.size());
  }
  _LIBCPP_HIDE_FROM_ABI byte_string to_bytes(const _Elem* __first, const _Elem* __last);

  _LIBCPP_HIDE_FROM_ABI size_t converted() const _NOEXCEPT { return __cvtcount_; }
  _LIBCPP_HIDE_FROM_ABI state_type state() const { return __cvtstate_; }
};

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Codecvt, class _Elem, class _WideAlloc, class _ByteAlloc>
inline wstring_convert<_Codecvt, _Elem, _WideAlloc, _ByteAlloc>::wstring_convert(_Codecvt* __pcvt)
    : __cvtptr_(__pcvt), __cvtstate_(), __cvtcount_(0) {}
_LIBCPP_SUPPRESS_DEPRECATED_POP

template <class _Codecvt, class _Elem, class _WideAlloc, class _ByteAlloc>
inline wstring_convert<_Codecvt, _Elem, _WideAlloc, _ByteAlloc>::wstring_convert(_Codecvt* __pcvt, state_type __state)
    : __cvtptr_(__pcvt), __cvtstate_(__state), __cvtcount_(0) {}

template <class _Codecvt, class _Elem, class _WideAlloc, class _ByteAlloc>
wstring_convert<_Codecvt, _Elem, _WideAlloc, _ByteAlloc>::wstring_convert(
    const byte_string& __byte_err, const wide_string& __wide_err)
    : __byte_err_string_(__byte_err), __wide_err_string_(__wide_err), __cvtstate_(), __cvtcount_(0) {
  __cvtptr_ = new _Codecvt;
}

#    ifndef _LIBCPP_CXX03_LANG

template <class _Codecvt, class _Elem, class _WideAlloc, class _ByteAlloc>
inline wstring_convert<_Codecvt, _Elem, _WideAlloc, _ByteAlloc>::wstring_convert(wstring_convert&& __wc)
    : __byte_err_string_(std::move(__wc.__byte_err_string_)),
      __wide_err_string_(std::move(__wc.__wide_err_string_)),
      __cvtptr_(__wc.__cvtptr_),
      __cvtstate_(__wc.__cvtstate_),
      __cvtcount_(__wc.__cvtcount_) {
  __wc.__cvtptr_ = nullptr;
}

#    endif // _LIBCPP_CXX03_LANG

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Codecvt, class _Elem, class _WideAlloc, class _ByteAlloc>
wstring_convert<_Codecvt, _Elem, _WideAlloc, _ByteAlloc>::~wstring_convert() {
  delete __cvtptr_;
}

template <class _Codecvt, class _Elem, class _WideAlloc, class _ByteAlloc>
typename wstring_convert<_Codecvt, _Elem, _WideAlloc, _ByteAlloc>::wide_string
wstring_convert<_Codecvt, _Elem, _WideAlloc, _ByteAlloc>::from_bytes(const char* __frm, const char* __frm_end) {
  _LIBCPP_SUPPRESS_DEPRECATED_POP
  __cvtcount_ = 0;
  if (__cvtptr_ != nullptr) {
    wide_string __ws(2 * (__frm_end - __frm), _Elem());
    if (__frm != __frm_end)
      __ws.resize(__ws.capacity());
    codecvt_base::result __r = codecvt_base::ok;
    state_type __st          = __cvtstate_;
    if (__frm != __frm_end) {
      _Elem* __to     = std::addressof(__ws[0]);
      _Elem* __to_end = __to + __ws.size();
      const char* __frm_nxt;
      do {
        _Elem* __to_nxt;
        __r = __cvtptr_->in(__st, __frm, __frm_end, __frm_nxt, __to, __to_end, __to_nxt);
        __cvtcount_ += __frm_nxt - __frm;
        if (__frm_nxt == __frm) {
          __r = codecvt_base::error;
        } else if (__r == codecvt_base::noconv) {
          __ws.resize(__to - std::addressof(__ws[0]));
          // This only gets executed if _Elem is char
          __ws.append((const _Elem*)__frm, (const _Elem*)__frm_end);
          __frm = __frm_nxt;
          __r   = codecvt_base::ok;
        } else if (__r == codecvt_base::ok) {
          __ws.resize(__to_nxt - std::addressof(__ws[0]));
          __frm = __frm_nxt;
        } else if (__r == codecvt_base::partial) {
          ptrdiff_t __s = __to_nxt - std::addressof(__ws[0]);
          __ws.resize(2 * __s);
          __to     = std::addressof(__ws[0]) + __s;
          __to_end = std::addressof(__ws[0]) + __ws.size();
          __frm    = __frm_nxt;
        }
      } while (__r == codecvt_base::partial && __frm_nxt < __frm_end);
    }
    if (__r == codecvt_base::ok)
      return __ws;
  }

  if (__wide_err_string_.empty())
    std::__throw_range_error("wstring_convert: from_bytes error");

  return __wide_err_string_;
}

template <class _Codecvt, class _Elem, class _WideAlloc, class _ByteAlloc>
typename wstring_convert<_Codecvt, _Elem, _WideAlloc, _ByteAlloc>::byte_string
wstring_convert<_Codecvt, _Elem, _WideAlloc, _ByteAlloc>::to_bytes(const _Elem* __frm, const _Elem* __frm_end) {
  __cvtcount_ = 0;
  if (__cvtptr_ != nullptr) {
    byte_string __bs(2 * (__frm_end - __frm), char());
    if (__frm != __frm_end)
      __bs.resize(__bs.capacity());
    codecvt_base::result __r = codecvt_base::ok;
    state_type __st          = __cvtstate_;
    if (__frm != __frm_end) {
      char* __to     = std::addressof(__bs[0]);
      char* __to_end = __to + __bs.size();
      const _Elem* __frm_nxt;
      do {
        char* __to_nxt;
        __r = __cvtptr_->out(__st, __frm, __frm_end, __frm_nxt, __to, __to_end, __to_nxt);
        __cvtcount_ += __frm_nxt - __frm;
        if (__frm_nxt == __frm) {
          __r = codecvt_base::error;
        } else if (__r == codecvt_base::noconv) {
          __bs.resize(__to - std::addressof(__bs[0]));
          // This only gets executed if _Elem is char
          __bs.append((const char*)__frm, (const char*)__frm_end);
          __frm = __frm_nxt;
          __r   = codecvt_base::ok;
        } else if (__r == codecvt_base::ok) {
          __bs.resize(__to_nxt - std::addressof(__bs[0]));
          __frm = __frm_nxt;
        } else if (__r == codecvt_base::partial) {
          ptrdiff_t __s = __to_nxt - std::addressof(__bs[0]);
          __bs.resize(2 * __s);
          __to     = std::addressof(__bs[0]) + __s;
          __to_end = std::addressof(__bs[0]) + __bs.size();
          __frm    = __frm_nxt;
        }
      } while (__r == codecvt_base::partial && __frm_nxt < __frm_end);
    }
    if (__r == codecvt_base::ok) {
      size_t __s = __bs.size();
      __bs.resize(__bs.capacity());
      char* __to     = std::addressof(__bs[0]) + __s;
      char* __to_end = __to + __bs.size();
      do {
        char* __to_nxt;
        __r = __cvtptr_->unshift(__st, __to, __to_end, __to_nxt);
        if (__r == codecvt_base::noconv) {
          __bs.resize(__to - std::addressof(__bs[0]));
          __r = codecvt_base::ok;
        } else if (__r == codecvt_base::ok) {
          __bs.resize(__to_nxt - std::addressof(__bs[0]));
        } else if (__r == codecvt_base::partial) {
          ptrdiff_t __sp = __to_nxt - std::addressof(__bs[0]);
          __bs.resize(2 * __sp);
          __to     = std::addressof(__bs[0]) + __sp;
          __to_end = std::addressof(__bs[0]) + __bs.size();
        }
      } while (__r == codecvt_base::partial);
      if (__r == codecvt_base::ok)
        return __bs;
    }
  }

  if (__byte_err_string_.empty())
    std::__throw_range_error("wstring_convert: to_bytes error");

  return __byte_err_string_;
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#  endif // _LIBCPP_STD_VER < 26 || defined(_LIBCPP_ENABLE_CXX26_REMOVED_WSTRING_CONVERT)

#endif // _LIBCPP_HAS_LOCALIZATION

#endif // _LIBCPP___LOCALE_DIR_WSTRING_CONVERT_H
