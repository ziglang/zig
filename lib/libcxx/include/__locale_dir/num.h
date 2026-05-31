//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___LOCALE_DIR_NUM_H
#define _LIBCPP___LOCALE_DIR_NUM_H

#include <__algorithm/find.h>
#include <__algorithm/reverse.h>
#include <__charconv/to_chars_integral.h>
#include <__charconv/traits.h>
#include <__config>
#include <__iterator/istreambuf_iterator.h>
#include <__iterator/ostreambuf_iterator.h>
#include <__locale_dir/check_grouping.h>
#include <__locale_dir/get_c_locale.h>
#include <__locale_dir/pad_and_output.h>
#include <__locale_dir/scan_keyword.h>
#include <__memory/unique_ptr.h>
#include <__system_error/errc.h>
#include <cerrno>
#include <ios>
#include <streambuf>

#if _LIBCPP_HAS_LOCALIZATION

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

// TODO: Properly qualify calls now that the locale base API defines functions instead of macros
// NOLINTBEGIN(libcpp-robust-against-adl)

_LIBCPP_PUSH_MACROS
#  include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

struct _LIBCPP_EXPORTED_FROM_ABI __num_get_base {
  static const int __num_get_buf_sz = 40;

  static int __get_base(ios_base&);
  static const char __src[33]; // "0123456789abcdefABCDEFxX+-pPiInN"
  // count of leading characters in __src used for parsing integers ("012..X+-")
  static const size_t __int_chr_cnt = 26;
  // count of leading characters in __src used for parsing floating-point values ("012..-pP")
  static const size_t __fp_chr_cnt = 28;
};

template <class _CharT>
struct __num_get : protected __num_get_base {
  static string __stage2_float_prep(ios_base& __iob, _CharT* __atoms, _CharT& __decimal_point, _CharT& __thousands_sep);

  static int __stage2_float_loop(
      _CharT __ct,
      bool& __in_units,
      char& __exp,
      char* __a,
      char*& __a_end,
      _CharT __decimal_point,
      _CharT __thousands_sep,
      const string& __grouping,
      unsigned* __g,
      unsigned*& __g_end,
      unsigned& __dc,
      _CharT* __atoms);

  [[__deprecated__("This exists only for ABI compatibility")]] static string
  __stage2_int_prep(ios_base& __iob, _CharT* __atoms, _CharT& __thousands_sep);
  static int __stage2_int_loop(
      _CharT __ct,
      int __base,
      char* __a,
      char*& __a_end,
      unsigned& __dc,
      _CharT __thousands_sep,
      const string& __grouping,
      unsigned* __g,
      unsigned*& __g_end,
      _CharT* __atoms);

  _LIBCPP_HIDE_FROM_ABI static string __stage2_int_prep(ios_base& __iob, _CharT& __thousands_sep) {
    locale __loc                 = __iob.getloc();
    const numpunct<_CharT>& __np = use_facet<numpunct<_CharT> >(__loc);
    __thousands_sep              = __np.thousands_sep();
    return __np.grouping();
  }

  _LIBCPP_HIDE_FROM_ABI const _CharT* __do_widen(ios_base& __iob, _CharT* __atoms) const {
    return __do_widen_p(__iob, __atoms);
  }

private:
  template <typename _Tp>
  _LIBCPP_HIDE_FROM_ABI const _Tp* __do_widen_p(ios_base& __iob, _Tp* __atoms) const {
    locale __loc = __iob.getloc();
    use_facet<ctype<_Tp> >(__loc).widen(__src, __src + __int_chr_cnt, __atoms);
    return __atoms;
  }

  _LIBCPP_HIDE_FROM_ABI const char* __do_widen_p(ios_base& __iob, char* __atoms) const {
    (void)__iob;
    (void)__atoms;
    return __src;
  }
};

template <class _CharT>
string __num_get<_CharT>::__stage2_float_prep(
    ios_base& __iob, _CharT* __atoms, _CharT& __decimal_point, _CharT& __thousands_sep) {
  locale __loc = __iob.getloc();
  std::use_facet<ctype<_CharT> >(__loc).widen(__src, __src + __fp_chr_cnt, __atoms);
  const numpunct<_CharT>& __np = std::use_facet<numpunct<_CharT> >(__loc);
  __decimal_point              = __np.decimal_point();
  __thousands_sep              = __np.thousands_sep();
  return __np.grouping();
}

template <class _CharT>
int __num_get<_CharT>::__stage2_int_loop(
    _CharT __ct,
    int __base,
    char* __a,
    char*& __a_end,
    unsigned& __dc,
    _CharT __thousands_sep,
    const string& __grouping,
    unsigned* __g,
    unsigned*& __g_end,
    _CharT* __atoms) {
  if (__a_end == __a && (__ct == __atoms[24] || __ct == __atoms[25])) {
    *__a_end++ = __ct == __atoms[24] ? '+' : '-';
    __dc       = 0;
    return 0;
  }
  if (__grouping.size() != 0 && __ct == __thousands_sep) {
    if (__g_end - __g < __num_get_buf_sz) {
      *__g_end++ = __dc;
      __dc       = 0;
    }
    return 0;
  }
  ptrdiff_t __f = std::find(__atoms, __atoms + __int_chr_cnt, __ct) - __atoms;
  if (__f >= 24)
    return -1;
  switch (__base) {
  case 8:
  case 10:
    if (__f >= __base)
      return -1;
    break;
  case 16:
    if (__f < 22)
      break;
    if (__a_end != __a && __a_end - __a <= 2 && __a_end[-1] == '0') {
      __dc       = 0;
      *__a_end++ = __src[__f];
      return 0;
    }
    return -1;
  }
  *__a_end++ = __src[__f];
  ++__dc;
  return 0;
}

template <class _CharT>
int __num_get<_CharT>::__stage2_float_loop(
    _CharT __ct,
    bool& __in_units,
    char& __exp,
    char* __a,
    char*& __a_end,
    _CharT __decimal_point,
    _CharT __thousands_sep,
    const string& __grouping,
    unsigned* __g,
    unsigned*& __g_end,
    unsigned& __dc,
    _CharT* __atoms) {
  if (__ct == __decimal_point) {
    if (!__in_units)
      return -1;
    __in_units = false;
    *__a_end++ = '.';
    if (__grouping.size() != 0 && __g_end - __g < __num_get_buf_sz)
      *__g_end++ = __dc;
    return 0;
  }
  if (__ct == __thousands_sep && __grouping.size() != 0) {
    if (!__in_units)
      return -1;
    if (__g_end - __g < __num_get_buf_sz) {
      *__g_end++ = __dc;
      __dc       = 0;
    }
    return 0;
  }
  ptrdiff_t __f = std::find(__atoms, __atoms + __num_get_base::__fp_chr_cnt, __ct) - __atoms;
  if (__f >= static_cast<ptrdiff_t>(__num_get_base::__fp_chr_cnt))
    return -1;
  char __x = __src[__f];
  if (__x == '-' || __x == '+') {
    if (__a_end == __a || (std::toupper(__a_end[-1]) == std::toupper(__exp))) {
      *__a_end++ = __x;
      return 0;
    }
    return -1;
  }
  if (__x == 'x' || __x == 'X')
    __exp = 'P';
  else if (std::toupper(__x) == __exp) {
    __exp = std::tolower(__exp);
    if (__in_units) {
      __in_units = false;
      if (__grouping.size() != 0 && __g_end - __g < __num_get_buf_sz)
        *__g_end++ = __dc;
    }
  }
  *__a_end++ = __x;
  if (__f >= 22)
    return 0;
  ++__dc;
  return 0;
}

extern template struct _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS __num_get<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template struct _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS __num_get<wchar_t>;
#  endif

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __do_strtod(const char* __a, char** __p2);

template <>
inline _LIBCPP_HIDE_FROM_ABI float __do_strtod<float>(const char* __a, char** __p2) {
  return __locale::__strtof(__a, __p2, _LIBCPP_GET_C_LOCALE);
}

template <>
inline _LIBCPP_HIDE_FROM_ABI double __do_strtod<double>(const char* __a, char** __p2) {
  return __locale::__strtod(__a, __p2, _LIBCPP_GET_C_LOCALE);
}

template <>
inline _LIBCPP_HIDE_FROM_ABI long double __do_strtod<long double>(const char* __a, char** __p2) {
  return __locale::__strtold(__a, __p2, _LIBCPP_GET_C_LOCALE);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __num_get_float(const char* __a, const char* __a_end, ios_base::iostate& __err) {
  if (__a != __a_end) {
    __libcpp_remove_reference_t<decltype(errno)> __save_errno = errno;
    errno                                                     = 0;
    char* __p2;
    _Tp __ld                                                     = std::__do_strtod<_Tp>(__a, &__p2);
    __libcpp_remove_reference_t<decltype(errno)> __current_errno = errno;
    if (__current_errno == 0)
      errno = __save_errno;
    if (__p2 != __a_end) {
      __err = ios_base::failbit;
      return 0;
    } else if (__current_errno == ERANGE)
      __err = ios_base::failbit;
    return __ld;
  }
  __err = ios_base::failbit;
  return 0;
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__num_get_signed_integral(const char* __a, const char* __a_end, ios_base::iostate& __err, int __base) {
  if (__a != __a_end) {
    __libcpp_remove_reference_t<decltype(errno)> __save_errno = errno;
    errno                                                     = 0;
    char* __p2;
    long long __ll = __locale::__strtoll(__a, &__p2, __base, _LIBCPP_GET_C_LOCALE);
    __libcpp_remove_reference_t<decltype(errno)> __current_errno = errno;
    if (__current_errno == 0)
      errno = __save_errno;
    if (__p2 != __a_end) {
      __err = ios_base::failbit;
      return 0;
    } else if (__current_errno == ERANGE || __ll < numeric_limits<_Tp>::min() || numeric_limits<_Tp>::max() < __ll) {
      __err = ios_base::failbit;
      if (__ll > 0)
        return numeric_limits<_Tp>::max();
      else
        return numeric_limits<_Tp>::min();
    }
    return static_cast<_Tp>(__ll);
  }
  __err = ios_base::failbit;
  return 0;
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__num_get_unsigned_integral(const char* __a, const char* __a_end, ios_base::iostate& __err, int __base) {
  if (__a != __a_end) {
    const bool __negate = *__a == '-';
    if (__negate && ++__a == __a_end) {
      __err = ios_base::failbit;
      return 0;
    }
    __libcpp_remove_reference_t<decltype(errno)> __save_errno = errno;
    errno                                                     = 0;
    char* __p2;
    unsigned long long __ll = __locale::__strtoull(__a, &__p2, __base, _LIBCPP_GET_C_LOCALE);
    __libcpp_remove_reference_t<decltype(errno)> __current_errno = errno;
    if (__current_errno == 0)
      errno = __save_errno;
    if (__p2 != __a_end) {
      __err = ios_base::failbit;
      return 0;
    } else if (__current_errno == ERANGE || numeric_limits<_Tp>::max() < __ll) {
      __err = ios_base::failbit;
      return numeric_limits<_Tp>::max();
    }
    _Tp __res = static_cast<_Tp>(__ll);
    if (__negate)
      __res = -__res;
    return __res;
  }
  __err = ios_base::failbit;
  return 0;
}

template <class _CharT, class _InputIterator = istreambuf_iterator<_CharT> >
class num_get : public locale::facet, private __num_get<_CharT> {
public:
  typedef _CharT char_type;
  typedef _InputIterator iter_type;

  _LIBCPP_HIDE_FROM_ABI explicit num_get(size_t __refs = 0) : locale::facet(__refs) {}

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, bool& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, long& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, long long& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, unsigned short& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, unsigned int& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, unsigned long& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, unsigned long long& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, float& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, double& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, long double& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, void*& __v) const {
    return do_get(__b, __e, __iob, __err, __v);
  }

  static locale::id id;

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~num_get() override {}

  template <class _Fp>
  _LIBCPP_HIDE_FROM_ABI iter_type
  __do_get_floating_point(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, _Fp& __v) const {
    // Stage 1, nothing to do
    // Stage 2
    char_type __atoms[__num_get_base::__fp_chr_cnt];
    char_type __decimal_point;
    char_type __thousands_sep;
    string __grouping = this->__stage2_float_prep(__iob, __atoms, __decimal_point, __thousands_sep);
    string __buf;
    __buf.resize(__buf.capacity());
    char* __a     = &__buf[0];
    char* __a_end = __a;
    unsigned __g[__num_get_base::__num_get_buf_sz];
    unsigned* __g_end        = __g;
    unsigned __dc            = 0;
    bool __in_units          = true;
    char __exp               = 'E';
    bool __is_leading_parsed = false;
    for (; __b != __e; ++__b) {
      if (__a_end == __a + __buf.size()) {
        size_t __tmp = __buf.size();
        __buf.resize(2 * __buf.size());
        __buf.resize(__buf.capacity());
        __a     = &__buf[0];
        __a_end = __a + __tmp;
      }
      if (this->__stage2_float_loop(
              *__b,
              __in_units,
              __exp,
              __a,
              __a_end,
              __decimal_point,
              __thousands_sep,
              __grouping,
              __g,
              __g_end,
              __dc,
              __atoms))
        break;

      // the leading character excluding the sign must be a decimal digit
      if (!__is_leading_parsed) {
        if (__a_end - __a >= 1 && __a[0] != '-' && __a[0] != '+') {
          if (('0' <= __a[0] && __a[0] <= '9') || __a[0] == '.')
            __is_leading_parsed = true;
          else
            break;
        } else if (__a_end - __a >= 2 && (__a[0] == '-' || __a[0] == '+')) {
          if (('0' <= __a[1] && __a[1] <= '9') || __a[1] == '.')
            __is_leading_parsed = true;
          else
            break;
        }
      }
    }
    if (__grouping.size() != 0 && __in_units && __g_end - __g < __num_get_base::__num_get_buf_sz)
      *__g_end++ = __dc;
    // Stage 3
    __v = std::__num_get_float<_Fp>(__a, __a_end, __err);
    // Digit grouping checked
    __check_grouping(__grouping, __g, __g_end, __err);
    // EOF checked
    if (__b == __e)
      __err |= ios_base::eofbit;
    return __b;
  }

  template <class _Signed>
  _LIBCPP_HIDE_FROM_ABI iter_type
  __do_get_signed(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, _Signed& __v) const {
    // Stage 1
    int __base = this->__get_base(__iob);
    // Stage 2
    char_type __thousands_sep;
    const int __atoms_size = __num_get_base::__int_chr_cnt;
    char_type __atoms1[__atoms_size];
    const char_type* __atoms = this->__do_widen(__iob, __atoms1);
    string __grouping        = this->__stage2_int_prep(__iob, __thousands_sep);
    string __buf;
    __buf.resize(__buf.capacity());
    char* __a     = &__buf[0];
    char* __a_end = __a;
    unsigned __g[__num_get_base::__num_get_buf_sz];
    unsigned* __g_end = __g;
    unsigned __dc     = 0;
    for (; __b != __e; ++__b) {
      if (__a_end == __a + __buf.size()) {
        size_t __tmp = __buf.size();
        __buf.resize(2 * __buf.size());
        __buf.resize(__buf.capacity());
        __a     = &__buf[0];
        __a_end = __a + __tmp;
      }
      if (this->__stage2_int_loop(
              *__b,
              __base,
              __a,
              __a_end,
              __dc,
              __thousands_sep,
              __grouping,
              __g,
              __g_end,
              const_cast<char_type*>(__atoms)))
        break;
    }
    if (__grouping.size() != 0 && __g_end - __g < __num_get_base::__num_get_buf_sz)
      *__g_end++ = __dc;
    // Stage 3
    __v = std::__num_get_signed_integral<_Signed>(__a, __a_end, __err, __base);
    // Digit grouping checked
    __check_grouping(__grouping, __g, __g_end, __err);
    // EOF checked
    if (__b == __e)
      __err |= ios_base::eofbit;
    return __b;
  }

  template <class _Unsigned>
  _LIBCPP_HIDE_FROM_ABI iter_type
  __do_get_unsigned(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, _Unsigned& __v) const {
    // Stage 1
    int __base = this->__get_base(__iob);
    // Stage 2
    char_type __thousands_sep;
    const int __atoms_size = __num_get_base::__int_chr_cnt;
    char_type __atoms1[__atoms_size];
    const char_type* __atoms = this->__do_widen(__iob, __atoms1);
    string __grouping        = this->__stage2_int_prep(__iob, __thousands_sep);
    string __buf;
    __buf.resize(__buf.capacity());
    char* __a     = &__buf[0];
    char* __a_end = __a;
    unsigned __g[__num_get_base::__num_get_buf_sz];
    unsigned* __g_end = __g;
    unsigned __dc     = 0;
    for (; __b != __e; ++__b) {
      if (__a_end == __a + __buf.size()) {
        size_t __tmp = __buf.size();
        __buf.resize(2 * __buf.size());
        __buf.resize(__buf.capacity());
        __a     = &__buf[0];
        __a_end = __a + __tmp;
      }
      if (this->__stage2_int_loop(
              *__b,
              __base,
              __a,
              __a_end,
              __dc,
              __thousands_sep,
              __grouping,
              __g,
              __g_end,
              const_cast<char_type*>(__atoms)))
        break;
    }
    if (__grouping.size() != 0 && __g_end - __g < __num_get_base::__num_get_buf_sz)
      *__g_end++ = __dc;
    // Stage 3
    __v = std::__num_get_unsigned_integral<_Unsigned>(__a, __a_end, __err, __base);
    // Digit grouping checked
    __check_grouping(__grouping, __g, __g_end, __err);
    // EOF checked
    if (__b == __e)
      __err |= ios_base::eofbit;
    return __b;
  }

  virtual iter_type do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, bool& __v) const;

  virtual iter_type do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, long& __v) const {
    return this->__do_get_signed(__b, __e, __iob, __err, __v);
  }

  virtual iter_type
  do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, long long& __v) const {
    return this->__do_get_signed(__b, __e, __iob, __err, __v);
  }

  virtual iter_type
  do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, unsigned short& __v) const {
    return this->__do_get_unsigned(__b, __e, __iob, __err, __v);
  }

  virtual iter_type
  do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, unsigned int& __v) const {
    return this->__do_get_unsigned(__b, __e, __iob, __err, __v);
  }

  virtual iter_type
  do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, unsigned long& __v) const {
    return this->__do_get_unsigned(__b, __e, __iob, __err, __v);
  }

  virtual iter_type
  do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, unsigned long long& __v) const {
    return this->__do_get_unsigned(__b, __e, __iob, __err, __v);
  }

  virtual iter_type do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, float& __v) const {
    return this->__do_get_floating_point(__b, __e, __iob, __err, __v);
  }

  virtual iter_type do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, double& __v) const {
    return this->__do_get_floating_point(__b, __e, __iob, __err, __v);
  }

  virtual iter_type
  do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, long double& __v) const {
    return this->__do_get_floating_point(__b, __e, __iob, __err, __v);
  }

  virtual iter_type do_get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, void*& __v) const;
};

template <class _CharT, class _InputIterator>
locale::id num_get<_CharT, _InputIterator>::id;

template <class _CharT, class _InputIterator>
_InputIterator num_get<_CharT, _InputIterator>::do_get(
    iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, bool& __v) const {
  if ((__iob.flags() & ios_base::boolalpha) == 0) {
    long __lv = -1;
    __b       = do_get(__b, __e, __iob, __err, __lv);
    switch (__lv) {
    case 0:
      __v = false;
      break;
    case 1:
      __v = true;
      break;
    default:
      __v   = true;
      __err = ios_base::failbit;
      break;
    }
    return __b;
  }
  const ctype<_CharT>& __ct    = std::use_facet<ctype<_CharT> >(__iob.getloc());
  const numpunct<_CharT>& __np = std::use_facet<numpunct<_CharT> >(__iob.getloc());
  typedef typename numpunct<_CharT>::string_type string_type;
  const string_type __names[2] = {__np.truename(), __np.falsename()};
  const string_type* __i       = std::__scan_keyword(__b, __e, __names, __names + 2, __ct, __err);
  __v                          = __i == __names;
  return __b;
}

template <class _CharT, class _InputIterator>
_InputIterator num_get<_CharT, _InputIterator>::do_get(
    iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, void*& __v) const {
  // Stage 1
  int __base = 16;
  // Stage 2
  char_type __atoms[__num_get_base::__int_chr_cnt];
  char_type __thousands_sep = char_type();
  string __grouping;
  std::use_facet<ctype<_CharT> >(__iob.getloc())
      .widen(__num_get_base::__src, __num_get_base::__src + __num_get_base::__int_chr_cnt, __atoms);
  string __buf;
  __buf.resize(__buf.capacity());
  char* __a     = &__buf[0];
  char* __a_end = __a;
  unsigned __g[__num_get_base::__num_get_buf_sz];
  unsigned* __g_end = __g;
  unsigned __dc     = 0;
  for (; __b != __e; ++__b) {
    if (__a_end == __a + __buf.size()) {
      size_t __tmp = __buf.size();
      __buf.resize(2 * __buf.size());
      __buf.resize(__buf.capacity());
      __a     = &__buf[0];
      __a_end = __a + __tmp;
    }
    if (this->__stage2_int_loop(*__b, __base, __a, __a_end, __dc, __thousands_sep, __grouping, __g, __g_end, __atoms))
      break;
  }
  // Stage 3
  __buf.resize(__a_end - __a);
  if (__locale::__sscanf(__buf.c_str(), _LIBCPP_GET_C_LOCALE, "%p", &__v) != 1)
    __err = ios_base::failbit;
  // EOF checked
  if (__b == __e)
    __err |= ios_base::eofbit;
  return __b;
}

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS num_get<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS num_get<wchar_t>;
#  endif

struct _LIBCPP_EXPORTED_FROM_ABI __num_put_base {
protected:
  static void __format_int(char* __fmt, const char* __len, bool __signd, ios_base::fmtflags __flags);
  static bool __format_float(char* __fmt, const char* __len, ios_base::fmtflags __flags);
  static char* __identify_padding(char* __nb, char* __ne, const ios_base& __iob);
};

template <class _CharT>
struct __num_put : protected __num_put_base {
  static void __widen_and_group_int(
      char* __nb, char* __np, char* __ne, _CharT* __ob, _CharT*& __op, _CharT*& __oe, const locale& __loc);
  static void __widen_and_group_float(
      char* __nb, char* __np, char* __ne, _CharT* __ob, _CharT*& __op, _CharT*& __oe, const locale& __loc);
};

template <class _CharT>
void __num_put<_CharT>::__widen_and_group_int(
    char* __nb, char* __np, char* __ne, _CharT* __ob, _CharT*& __op, _CharT*& __oe, const locale& __loc) {
  const ctype<_CharT>& __ct     = std::use_facet<ctype<_CharT> >(__loc);
  const numpunct<_CharT>& __npt = std::use_facet<numpunct<_CharT> >(__loc);
  string __grouping             = __npt.grouping();
  if (__grouping.empty()) {
    __ct.widen(__nb, __ne, __ob);
    __oe = __ob + (__ne - __nb);
  } else {
    __oe       = __ob;
    char* __nf = __nb;
    if (*__nf == '-' || *__nf == '+')
      *__oe++ = __ct.widen(*__nf++);
    if (__ne - __nf >= 2 && __nf[0] == '0' && (__nf[1] == 'x' || __nf[1] == 'X')) {
      *__oe++ = __ct.widen(*__nf++);
      *__oe++ = __ct.widen(*__nf++);
    }
    std::reverse(__nf, __ne);
    _CharT __thousands_sep = __npt.thousands_sep();
    unsigned __dc          = 0;
    unsigned __dg          = 0;
    for (char* __p = __nf; __p < __ne; ++__p) {
      if (static_cast<unsigned>(__grouping[__dg]) > 0 && __dc == static_cast<unsigned>(__grouping[__dg])) {
        *__oe++ = __thousands_sep;
        __dc    = 0;
        if (__dg < __grouping.size() - 1)
          ++__dg;
      }
      *__oe++ = __ct.widen(*__p);
      ++__dc;
    }
    std::reverse(__ob + (__nf - __nb), __oe);
  }
  if (__np == __ne)
    __op = __oe;
  else
    __op = __ob + (__np - __nb);
}

template <class _CharT>
void __num_put<_CharT>::__widen_and_group_float(
    char* __nb, char* __np, char* __ne, _CharT* __ob, _CharT*& __op, _CharT*& __oe, const locale& __loc) {
  const ctype<_CharT>& __ct     = std::use_facet<ctype<_CharT> >(__loc);
  const numpunct<_CharT>& __npt = std::use_facet<numpunct<_CharT> >(__loc);
  string __grouping             = __npt.grouping();
  __oe                          = __ob;
  char* __nf                    = __nb;
  if (*__nf == '-' || *__nf == '+')
    *__oe++ = __ct.widen(*__nf++);
  char* __ns;
  if (__ne - __nf >= 2 && __nf[0] == '0' && (__nf[1] == 'x' || __nf[1] == 'X')) {
    *__oe++ = __ct.widen(*__nf++);
    *__oe++ = __ct.widen(*__nf++);
    for (__ns = __nf; __ns < __ne; ++__ns)
      if (!__locale::__isxdigit(*__ns, _LIBCPP_GET_C_LOCALE))
        break;
  } else {
    for (__ns = __nf; __ns < __ne; ++__ns)
      if (!__locale::__isdigit(*__ns, _LIBCPP_GET_C_LOCALE))
        break;
  }
  if (__grouping.empty()) {
    __ct.widen(__nf, __ns, __oe);
    __oe += __ns - __nf;
  } else {
    std::reverse(__nf, __ns);
    _CharT __thousands_sep = __npt.thousands_sep();
    unsigned __dc          = 0;
    unsigned __dg          = 0;
    for (char* __p = __nf; __p < __ns; ++__p) {
      if (__grouping[__dg] > 0 && __dc == static_cast<unsigned>(__grouping[__dg])) {
        *__oe++ = __thousands_sep;
        __dc    = 0;
        if (__dg < __grouping.size() - 1)
          ++__dg;
      }
      *__oe++ = __ct.widen(*__p);
      ++__dc;
    }
    std::reverse(__ob + (__nf - __nb), __oe);
  }
  for (__nf = __ns; __nf < __ne; ++__nf) {
    if (*__nf == '.') {
      *__oe++ = __npt.decimal_point();
      ++__nf;
      break;
    } else
      *__oe++ = __ct.widen(*__nf);
  }
  __ct.widen(__nf, __ne, __oe);
  __oe += __ne - __nf;
  if (__np == __ne)
    __op = __oe;
  else
    __op = __ob + (__np - __nb);
}

extern template struct _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS __num_put<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template struct _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS __num_put<wchar_t>;
#  endif

template <class _CharT, class _OutputIterator = ostreambuf_iterator<_CharT> >
class num_put : public locale::facet, private __num_put<_CharT> {
public:
  typedef _CharT char_type;
  typedef _OutputIterator iter_type;

  _LIBCPP_HIDE_FROM_ABI explicit num_put(size_t __refs = 0) : locale::facet(__refs) {}

  _LIBCPP_HIDE_FROM_ABI iter_type put(iter_type __s, ios_base& __iob, char_type __fl, bool __v) const {
    return do_put(__s, __iob, __fl, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type put(iter_type __s, ios_base& __iob, char_type __fl, long __v) const {
    return do_put(__s, __iob, __fl, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type put(iter_type __s, ios_base& __iob, char_type __fl, long long __v) const {
    return do_put(__s, __iob, __fl, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type put(iter_type __s, ios_base& __iob, char_type __fl, unsigned long __v) const {
    return do_put(__s, __iob, __fl, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type put(iter_type __s, ios_base& __iob, char_type __fl, unsigned long long __v) const {
    return do_put(__s, __iob, __fl, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type put(iter_type __s, ios_base& __iob, char_type __fl, double __v) const {
    return do_put(__s, __iob, __fl, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type put(iter_type __s, ios_base& __iob, char_type __fl, long double __v) const {
    return do_put(__s, __iob, __fl, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type put(iter_type __s, ios_base& __iob, char_type __fl, const void* __v) const {
    return do_put(__s, __iob, __fl, __v);
  }

  static locale::id id;

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~num_put() override {}

  virtual iter_type do_put(iter_type __s, ios_base& __iob, char_type __fl, bool __v) const;
  virtual iter_type do_put(iter_type __s, ios_base& __iob, char_type __fl, long __v) const;
  virtual iter_type do_put(iter_type __s, ios_base& __iob, char_type __fl, long long __v) const;
  virtual iter_type do_put(iter_type __s, ios_base& __iob, char_type __fl, unsigned long) const;
  virtual iter_type do_put(iter_type __s, ios_base& __iob, char_type __fl, unsigned long long) const;
  virtual iter_type do_put(iter_type __s, ios_base& __iob, char_type __fl, double __v) const;
  virtual iter_type do_put(iter_type __s, ios_base& __iob, char_type __fl, long double __v) const;
  virtual iter_type do_put(iter_type __s, ios_base& __iob, char_type __fl, const void* __v) const;

  template <class _Integral>
  _LIBCPP_HIDE_FROM_ABI inline _OutputIterator
  __do_put_integral(iter_type __s, ios_base& __iob, char_type __fl, _Integral __v) const;

  template <class _Float>
  _LIBCPP_HIDE_FROM_ABI inline _OutputIterator
  __do_put_floating_point(iter_type __s, ios_base& __iob, char_type __fl, _Float __v, char const* __len) const;
};

template <class _CharT, class _OutputIterator>
locale::id num_put<_CharT, _OutputIterator>::id;

template <class _CharT, class _OutputIterator>
_OutputIterator
num_put<_CharT, _OutputIterator>::do_put(iter_type __s, ios_base& __iob, char_type __fl, bool __v) const {
  if ((__iob.flags() & ios_base::boolalpha) == 0)
    return do_put(__s, __iob, __fl, (unsigned long)__v);
  const numpunct<char_type>& __np = std::use_facet<numpunct<char_type> >(__iob.getloc());
  typedef typename numpunct<char_type>::string_type string_type;
  string_type __nm = __v ? __np.truename() : __np.falsename();
  for (typename string_type::iterator __i = __nm.begin(); __i != __nm.end(); ++__i, ++__s)
    *__s = *__i;
  return __s;
}

template <class _CharT, class _OutputIterator>
template <class _Integral>
_LIBCPP_HIDE_FROM_ABI inline _OutputIterator num_put<_CharT, _OutputIterator>::__do_put_integral(
    iter_type __s, ios_base& __iob, char_type __fl, _Integral __v) const {
  // Stage 1 - Get number in narrow char

  // Worst case is octal, with showbase enabled. Note that octal is always
  // printed as an unsigned value.
  using _Unsigned = typename make_unsigned<_Integral>::type;
  _LIBCPP_CONSTEXPR const unsigned __buffer_size =
      (numeric_limits<_Unsigned>::digits / 3)          // 1 char per 3 bits
      + ((numeric_limits<_Unsigned>::digits % 3) != 0) // round up
      + 2;                                             // base prefix + terminating null character

  char __char_buffer[__buffer_size];
  char* __buffer_ptr = __char_buffer;

  auto __flags = __iob.flags();

  auto __basefield = (__flags & ios_base::basefield);

  // Extract base
  int __base = 10;
  if (__basefield == ios_base::oct)
    __base = 8;
  else if (__basefield == ios_base::hex)
    __base = 16;

  // Print '-' and make the argument unsigned
  auto __uval = std::__to_unsigned_like(__v);
  if (__basefield != ios_base::oct && __basefield != ios_base::hex && __v < 0) {
    *__buffer_ptr++ = '-';
    __uval          = std::__complement(__uval);
  }

  // Maybe add '+' prefix
  if (std::is_signed<_Integral>::value && (__flags & ios_base::showpos) && __basefield != ios_base::oct &&
      __basefield != ios_base::hex && __v >= 0)
    *__buffer_ptr++ = '+';

  // Add base prefix
  if (__v != 0 && __flags & ios_base::showbase) {
    if (__basefield == ios_base::oct) {
      *__buffer_ptr++ = '0';
    } else if (__basefield == ios_base::hex) {
      *__buffer_ptr++ = '0';
      *__buffer_ptr++ = (__flags & ios_base::uppercase ? 'X' : 'x');
    }
  }

  auto __res = std::__to_chars_integral(__buffer_ptr, __char_buffer + __buffer_size, __uval, __base);
  _LIBCPP_ASSERT_INTERNAL(__res.__ec == std::errc(0), "to_chars: invalid maximum buffer size computed?");

  // Make letters uppercase
  if (__flags & ios_base::hex && __flags & ios_base::uppercase) {
    for (; __buffer_ptr != __res.__ptr; ++__buffer_ptr)
      *__buffer_ptr = std::__hex_to_upper(*__buffer_ptr);
  }

  char* __np = this->__identify_padding(__char_buffer, __res.__ptr, __iob);
  // Stage 2 - Widen __nar while adding thousands separators
  char_type __o[2 * (__buffer_size - 1) - 1];
  char_type* __op; // pad here
  char_type* __oe; // end of output
  this->__widen_and_group_int(__char_buffer, __np, __res.__ptr, __o, __op, __oe, __iob.getloc());
  // [__o, __oe) contains thousands_sep'd wide number
  // Stage 3 & 4
  return std::__pad_and_output(__s, __o, __op, __oe, __iob, __fl);
}

template <class _CharT, class _OutputIterator>
_OutputIterator
num_put<_CharT, _OutputIterator>::do_put(iter_type __s, ios_base& __iob, char_type __fl, long __v) const {
  return this->__do_put_integral(__s, __iob, __fl, __v);
}

template <class _CharT, class _OutputIterator>
_OutputIterator
num_put<_CharT, _OutputIterator>::do_put(iter_type __s, ios_base& __iob, char_type __fl, long long __v) const {
  return this->__do_put_integral(__s, __iob, __fl, __v);
}

template <class _CharT, class _OutputIterator>
_OutputIterator
num_put<_CharT, _OutputIterator>::do_put(iter_type __s, ios_base& __iob, char_type __fl, unsigned long __v) const {
  return this->__do_put_integral(__s, __iob, __fl, __v);
}

template <class _CharT, class _OutputIterator>
_OutputIterator
num_put<_CharT, _OutputIterator>::do_put(iter_type __s, ios_base& __iob, char_type __fl, unsigned long long __v) const {
  return this->__do_put_integral(__s, __iob, __fl, __v);
}

template <class _CharT, class _OutputIterator>
template <class _Float>
_LIBCPP_HIDE_FROM_ABI inline _OutputIterator num_put<_CharT, _OutputIterator>::__do_put_floating_point(
    iter_type __s, ios_base& __iob, char_type __fl, _Float __v, char const* __len) const {
  // Stage 1 - Get number in narrow char
  char __fmt[8]            = {'%', 0};
  bool __specify_precision = this->__format_float(__fmt + 1, __len, __iob.flags());
  const unsigned __nbuf    = 30;
  char __nar[__nbuf];
  char* __nb = __nar;
  int __nc;
  _LIBCPP_DIAGNOSTIC_PUSH
  _LIBCPP_CLANG_DIAGNOSTIC_IGNORED("-Wformat-nonliteral")
  _LIBCPP_GCC_DIAGNOSTIC_IGNORED("-Wformat-nonliteral")
  if (__specify_precision)
    __nc = __locale::__snprintf(__nb, __nbuf, _LIBCPP_GET_C_LOCALE, __fmt, (int)__iob.precision(), __v);
  else
    __nc = __locale::__snprintf(__nb, __nbuf, _LIBCPP_GET_C_LOCALE, __fmt, __v);
  unique_ptr<char, void (*)(void*)> __nbh(nullptr, free);
  if (__nc > static_cast<int>(__nbuf - 1)) {
    if (__specify_precision)
      __nc = __locale::__asprintf(&__nb, _LIBCPP_GET_C_LOCALE, __fmt, (int)__iob.precision(), __v);
    else
      __nc = __locale::__asprintf(&__nb, _LIBCPP_GET_C_LOCALE, __fmt, __v);
    if (__nc == -1)
      std::__throw_bad_alloc();
    __nbh.reset(__nb);
  }
  _LIBCPP_DIAGNOSTIC_POP
  char* __ne = __nb + __nc;
  char* __np = this->__identify_padding(__nb, __ne, __iob);
  // Stage 2 - Widen __nar while adding thousands separators
  char_type __o[2 * (__nbuf - 1) - 1];
  char_type* __ob = __o;
  unique_ptr<char_type, void (*)(void*)> __obh(0, free);
  if (__nb != __nar) {
    __ob = (char_type*)malloc(2 * static_cast<size_t>(__nc) * sizeof(char_type));
    if (__ob == 0)
      std::__throw_bad_alloc();
    __obh.reset(__ob);
  }
  char_type* __op; // pad here
  char_type* __oe; // end of output
  this->__widen_and_group_float(__nb, __np, __ne, __ob, __op, __oe, __iob.getloc());
  // [__o, __oe) contains thousands_sep'd wide number
  // Stage 3 & 4
  __s = std::__pad_and_output(__s, __ob, __op, __oe, __iob, __fl);
  return __s;
}

template <class _CharT, class _OutputIterator>
_OutputIterator
num_put<_CharT, _OutputIterator>::do_put(iter_type __s, ios_base& __iob, char_type __fl, double __v) const {
  return this->__do_put_floating_point(__s, __iob, __fl, __v, "");
}

template <class _CharT, class _OutputIterator>
_OutputIterator
num_put<_CharT, _OutputIterator>::do_put(iter_type __s, ios_base& __iob, char_type __fl, long double __v) const {
  return this->__do_put_floating_point(__s, __iob, __fl, __v, "L");
}

template <class _CharT, class _OutputIterator>
_OutputIterator
num_put<_CharT, _OutputIterator>::do_put(iter_type __s, ios_base& __iob, char_type __fl, const void* __v) const {
  auto __flags = __iob.flags();
  __iob.flags((__flags & ~ios_base::basefield & ~ios_base::uppercase) | ios_base::hex | ios_base::showbase);
  auto __res = __do_put_integral(__s, __iob, __fl, reinterpret_cast<uintptr_t>(__v));
  __iob.flags(__flags);
  return __res;
}

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS num_put<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS num_put<wchar_t>;
#  endif

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

// NOLINTEND(libcpp-robust-against-adl)

#endif // _LIBCPP_HAS_LOCALIZATION

#endif // _LIBCPP___LOCALE_DIR_NUM_H
