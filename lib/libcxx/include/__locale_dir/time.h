//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___LOCALE_DIR_TIME_H
#define _LIBCPP___LOCALE_DIR_TIME_H

#include <__algorithm/copy.h>
#include <__config>
#include <__locale_dir/get_c_locale.h>
#include <__locale_dir/scan_keyword.h>
#include <ios>

#if _LIBCPP_HAS_LOCALIZATION

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _CharT, class _InputIterator>
_LIBCPP_HIDE_FROM_ABI int __get_up_to_n_digits(
    _InputIterator& __b, _InputIterator __e, ios_base::iostate& __err, const ctype<_CharT>& __ct, int __n) {
  // Precondition:  __n >= 1
  if (__b == __e) {
    __err |= ios_base::eofbit | ios_base::failbit;
    return 0;
  }
  // get first digit
  _CharT __c = *__b;
  if (!__ct.is(ctype_base::digit, __c)) {
    __err |= ios_base::failbit;
    return 0;
  }
  int __r = __ct.narrow(__c, 0) - '0';
  for (++__b, (void)--__n; __b != __e && __n > 0; ++__b, (void)--__n) {
    // get next digit
    __c = *__b;
    if (!__ct.is(ctype_base::digit, __c))
      return __r;
    __r = __r * 10 + __ct.narrow(__c, 0) - '0';
  }
  if (__b == __e)
    __err |= ios_base::eofbit;
  return __r;
}

class _LIBCPP_EXPORTED_FROM_ABI time_base {
public:
  enum dateorder { no_order, dmy, mdy, ymd, ydm };
};

template <class _CharT>
class __time_get_c_storage {
protected:
  typedef basic_string<_CharT> string_type;

  virtual const string_type* __weeks() const;
  virtual const string_type* __months() const;
  virtual const string_type* __am_pm() const;
  virtual const string_type& __c() const;
  virtual const string_type& __r() const;
  virtual const string_type& __x() const;
  virtual const string_type& __X() const;

  _LIBCPP_HIDE_FROM_ABI ~__time_get_c_storage() {}
};

template <>
_LIBCPP_EXPORTED_FROM_ABI const string* __time_get_c_storage<char>::__weeks() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const string* __time_get_c_storage<char>::__months() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const string* __time_get_c_storage<char>::__am_pm() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const string& __time_get_c_storage<char>::__c() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const string& __time_get_c_storage<char>::__r() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const string& __time_get_c_storage<char>::__x() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const string& __time_get_c_storage<char>::__X() const;

#  if _LIBCPP_HAS_WIDE_CHARACTERS
template <>
_LIBCPP_EXPORTED_FROM_ABI const wstring* __time_get_c_storage<wchar_t>::__weeks() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const wstring* __time_get_c_storage<wchar_t>::__months() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const wstring* __time_get_c_storage<wchar_t>::__am_pm() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const wstring& __time_get_c_storage<wchar_t>::__c() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const wstring& __time_get_c_storage<wchar_t>::__r() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const wstring& __time_get_c_storage<wchar_t>::__x() const;
template <>
_LIBCPP_EXPORTED_FROM_ABI const wstring& __time_get_c_storage<wchar_t>::__X() const;
#  endif

template <class _CharT, class _InputIterator = istreambuf_iterator<_CharT> >
class time_get : public locale::facet, public time_base, private __time_get_c_storage<_CharT> {
public:
  typedef _CharT char_type;
  typedef _InputIterator iter_type;
  typedef time_base::dateorder dateorder;
  typedef basic_string<char_type> string_type;

  _LIBCPP_HIDE_FROM_ABI explicit time_get(size_t __refs = 0) : locale::facet(__refs) {}

  _LIBCPP_HIDE_FROM_ABI dateorder date_order() const { return this->do_date_order(); }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get_time(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
    return do_get_time(__b, __e, __iob, __err, __tm);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get_date(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
    return do_get_date(__b, __e, __iob, __err, __tm);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get_weekday(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
    return do_get_weekday(__b, __e, __iob, __err, __tm);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get_monthname(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
    return do_get_monthname(__b, __e, __iob, __err, __tm);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get_year(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
    return do_get_year(__b, __e, __iob, __err, __tm);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm, char __fmt, char __mod = 0)
      const {
    return do_get(__b, __e, __iob, __err, __tm, __fmt, __mod);
  }

  iter_type
  get(iter_type __b,
      iter_type __e,
      ios_base& __iob,
      ios_base::iostate& __err,
      tm* __tm,
      const char_type* __fmtb,
      const char_type* __fmte) const;

  static locale::id id;

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~time_get() override {}

  virtual dateorder do_date_order() const;
  virtual iter_type
  do_get_time(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const;
  virtual iter_type
  do_get_date(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const;
  virtual iter_type
  do_get_weekday(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const;
  virtual iter_type
  do_get_monthname(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const;
  virtual iter_type
  do_get_year(iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const;
  virtual iter_type do_get(
      iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm, char __fmt, char __mod) const;

private:
  void __get_white_space(iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void __get_percent(iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;

  void __get_weekdayname(
      int& __m, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void __get_monthname(
      int& __m, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void __get_day(int& __d, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void
  __get_month(int& __m, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void
  __get_year(int& __y, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void
  __get_year4(int& __y, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void
  __get_hour(int& __d, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void
  __get_12_hour(int& __h, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void
  __get_am_pm(int& __h, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void
  __get_minute(int& __m, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void
  __get_second(int& __s, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void
  __get_weekday(int& __w, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
  void __get_day_year_num(
      int& __w, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const;
};

template <class _CharT, class _InputIterator>
locale::id time_get<_CharT, _InputIterator>::id;

// time_get primitives

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_weekdayname(
    int& __w, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  // Note:  ignoring case comes from the POSIX strptime spec
  const string_type* __wk = this->__weeks();
  ptrdiff_t __i           = std::__scan_keyword(__b, __e, __wk, __wk + 14, __ct, __err, false) - __wk;
  if (__i < 14)
    __w = __i % 7;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_monthname(
    int& __m, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  // Note:  ignoring case comes from the POSIX strptime spec
  const string_type* __month = this->__months();
  ptrdiff_t __i              = std::__scan_keyword(__b, __e, __month, __month + 24, __ct, __err, false) - __month;
  if (__i < 24)
    __m = __i % 12;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_day(
    int& __d, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 2);
  if (!(__err & ios_base::failbit) && 1 <= __t && __t <= 31)
    __d = __t;
  else
    __err |= ios_base::failbit;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_month(
    int& __m, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 2) - 1;
  if (!(__err & ios_base::failbit) && 0 <= __t && __t <= 11)
    __m = __t;
  else
    __err |= ios_base::failbit;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_year(
    int& __y, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 4);
  if (!(__err & ios_base::failbit)) {
    if (__t < 69)
      __t += 2000;
    else if (69 <= __t && __t <= 99)
      __t += 1900;
    __y = __t - 1900;
  }
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_year4(
    int& __y, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 4);
  if (!(__err & ios_base::failbit))
    __y = __t - 1900;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_hour(
    int& __h, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 2);
  if (!(__err & ios_base::failbit) && __t <= 23)
    __h = __t;
  else
    __err |= ios_base::failbit;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_12_hour(
    int& __h, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 2);
  if (!(__err & ios_base::failbit) && 1 <= __t && __t <= 12)
    __h = __t;
  else
    __err |= ios_base::failbit;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_minute(
    int& __m, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 2);
  if (!(__err & ios_base::failbit) && __t <= 59)
    __m = __t;
  else
    __err |= ios_base::failbit;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_second(
    int& __s, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 2);
  if (!(__err & ios_base::failbit) && __t <= 60)
    __s = __t;
  else
    __err |= ios_base::failbit;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_weekday(
    int& __w, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 1);
  if (!(__err & ios_base::failbit) && __t <= 6)
    __w = __t;
  else
    __err |= ios_base::failbit;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_day_year_num(
    int& __d, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  int __t = std::__get_up_to_n_digits(__b, __e, __err, __ct, 3);
  if (!(__err & ios_base::failbit) && __t <= 365)
    __d = __t;
  else
    __err |= ios_base::failbit;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_white_space(
    iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  for (; __b != __e && __ct.is(ctype_base::space, *__b); ++__b)
    ;
  if (__b == __e)
    __err |= ios_base::eofbit;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_am_pm(
    int& __h, iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  const string_type* __ap = this->__am_pm();
  if (__ap[0].size() + __ap[1].size() == 0) {
    __err |= ios_base::failbit;
    return;
  }
  ptrdiff_t __i = std::__scan_keyword(__b, __e, __ap, __ap + 2, __ct, __err, false) - __ap;
  if (__i == 0 && __h == 12)
    __h = 0;
  else if (__i == 1 && __h < 12)
    __h += 12;
}

template <class _CharT, class _InputIterator>
void time_get<_CharT, _InputIterator>::__get_percent(
    iter_type& __b, iter_type __e, ios_base::iostate& __err, const ctype<char_type>& __ct) const {
  if (__b == __e) {
    __err |= ios_base::eofbit | ios_base::failbit;
    return;
  }
  if (__ct.narrow(*__b, 0) != '%')
    __err |= ios_base::failbit;
  else if (++__b == __e)
    __err |= ios_base::eofbit;
}

// time_get end primitives

template <class _CharT, class _InputIterator>
_InputIterator time_get<_CharT, _InputIterator>::get(
    iter_type __b,
    iter_type __e,
    ios_base& __iob,
    ios_base::iostate& __err,
    tm* __tm,
    const char_type* __fmtb,
    const char_type* __fmte) const {
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__iob.getloc());
  __err                        = ios_base::goodbit;
  while (__fmtb != __fmte && __err == ios_base::goodbit) {
    if (__b == __e) {
      __err = ios_base::failbit;
      break;
    }
    if (__ct.narrow(*__fmtb, 0) == '%') {
      if (++__fmtb == __fmte) {
        __err = ios_base::failbit;
        break;
      }
      char __cmd = __ct.narrow(*__fmtb, 0);
      char __opt = '\0';
      if (__cmd == 'E' || __cmd == '0') {
        if (++__fmtb == __fmte) {
          __err = ios_base::failbit;
          break;
        }
        __opt = __cmd;
        __cmd = __ct.narrow(*__fmtb, 0);
      }
      __b = do_get(__b, __e, __iob, __err, __tm, __cmd, __opt);
      ++__fmtb;
    } else if (__ct.is(ctype_base::space, *__fmtb)) {
      for (++__fmtb; __fmtb != __fmte && __ct.is(ctype_base::space, *__fmtb); ++__fmtb)
        ;
      for (; __b != __e && __ct.is(ctype_base::space, *__b); ++__b)
        ;
    } else if (__ct.toupper(*__b) == __ct.toupper(*__fmtb)) {
      ++__b;
      ++__fmtb;
    } else
      __err = ios_base::failbit;
  }
  if (__b == __e)
    __err |= ios_base::eofbit;
  return __b;
}

template <class _CharT, class _InputIterator>
typename time_get<_CharT, _InputIterator>::dateorder time_get<_CharT, _InputIterator>::do_date_order() const {
  return mdy;
}

template <class _CharT, class _InputIterator>
_InputIterator time_get<_CharT, _InputIterator>::do_get_time(
    iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
  const char_type __fmt[] = {'%', 'H', ':', '%', 'M', ':', '%', 'S'};
  return get(__b, __e, __iob, __err, __tm, __fmt, __fmt + sizeof(__fmt) / sizeof(__fmt[0]));
}

template <class _CharT, class _InputIterator>
_InputIterator time_get<_CharT, _InputIterator>::do_get_date(
    iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
  const string_type& __fmt = this->__x();
  return get(__b, __e, __iob, __err, __tm, __fmt.data(), __fmt.data() + __fmt.size());
}

template <class _CharT, class _InputIterator>
_InputIterator time_get<_CharT, _InputIterator>::do_get_weekday(
    iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__iob.getloc());
  __get_weekdayname(__tm->tm_wday, __b, __e, __err, __ct);
  return __b;
}

template <class _CharT, class _InputIterator>
_InputIterator time_get<_CharT, _InputIterator>::do_get_monthname(
    iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__iob.getloc());
  __get_monthname(__tm->tm_mon, __b, __e, __err, __ct);
  return __b;
}

template <class _CharT, class _InputIterator>
_InputIterator time_get<_CharT, _InputIterator>::do_get_year(
    iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm) const {
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__iob.getloc());
  __get_year(__tm->tm_year, __b, __e, __err, __ct);
  return __b;
}

template <class _CharT, class _InputIterator>
_InputIterator time_get<_CharT, _InputIterator>::do_get(
    iter_type __b, iter_type __e, ios_base& __iob, ios_base::iostate& __err, tm* __tm, char __fmt, char) const {
  __err                        = ios_base::goodbit;
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__iob.getloc());
  switch (__fmt) {
  case 'a':
  case 'A':
    __get_weekdayname(__tm->tm_wday, __b, __e, __err, __ct);
    break;
  case 'b':
  case 'B':
  case 'h':
    __get_monthname(__tm->tm_mon, __b, __e, __err, __ct);
    break;
  case 'c': {
    const string_type& __fm = this->__c();
    __b                     = get(__b, __e, __iob, __err, __tm, __fm.data(), __fm.data() + __fm.size());
  } break;
  case 'd':
  case 'e':
    __get_day(__tm->tm_mday, __b, __e, __err, __ct);
    break;
  case 'D': {
    const char_type __fm[] = {'%', 'm', '/', '%', 'd', '/', '%', 'y'};
    __b                    = get(__b, __e, __iob, __err, __tm, __fm, __fm + sizeof(__fm) / sizeof(__fm[0]));
  } break;
  case 'F': {
    const char_type __fm[] = {'%', 'Y', '-', '%', 'm', '-', '%', 'd'};
    __b                    = get(__b, __e, __iob, __err, __tm, __fm, __fm + sizeof(__fm) / sizeof(__fm[0]));
  } break;
  case 'H':
    __get_hour(__tm->tm_hour, __b, __e, __err, __ct);
    break;
  case 'I':
    __get_12_hour(__tm->tm_hour, __b, __e, __err, __ct);
    break;
  case 'j':
    __get_day_year_num(__tm->tm_yday, __b, __e, __err, __ct);
    break;
  case 'm':
    __get_month(__tm->tm_mon, __b, __e, __err, __ct);
    break;
  case 'M':
    __get_minute(__tm->tm_min, __b, __e, __err, __ct);
    break;
  case 'n':
  case 't':
    __get_white_space(__b, __e, __err, __ct);
    break;
  case 'p':
    __get_am_pm(__tm->tm_hour, __b, __e, __err, __ct);
    break;
  case 'r': {
    const char_type __fm[] = {'%', 'I', ':', '%', 'M', ':', '%', 'S', ' ', '%', 'p'};
    __b                    = get(__b, __e, __iob, __err, __tm, __fm, __fm + sizeof(__fm) / sizeof(__fm[0]));
  } break;
  case 'R': {
    const char_type __fm[] = {'%', 'H', ':', '%', 'M'};
    __b                    = get(__b, __e, __iob, __err, __tm, __fm, __fm + sizeof(__fm) / sizeof(__fm[0]));
  } break;
  case 'S':
    __get_second(__tm->tm_sec, __b, __e, __err, __ct);
    break;
  case 'T': {
    const char_type __fm[] = {'%', 'H', ':', '%', 'M', ':', '%', 'S'};
    __b                    = get(__b, __e, __iob, __err, __tm, __fm, __fm + sizeof(__fm) / sizeof(__fm[0]));
  } break;
  case 'w':
    __get_weekday(__tm->tm_wday, __b, __e, __err, __ct);
    break;
  case 'x':
    return do_get_date(__b, __e, __iob, __err, __tm);
  case 'X': {
    const string_type& __fm = this->__X();
    __b                     = get(__b, __e, __iob, __err, __tm, __fm.data(), __fm.data() + __fm.size());
  } break;
  case 'y':
    __get_year(__tm->tm_year, __b, __e, __err, __ct);
    break;
  case 'Y':
    __get_year4(__tm->tm_year, __b, __e, __err, __ct);
    break;
  case '%':
    __get_percent(__b, __e, __err, __ct);
    break;
  default:
    __err |= ios_base::failbit;
  }
  return __b;
}

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS time_get<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS time_get<wchar_t>;
#  endif

class _LIBCPP_EXPORTED_FROM_ABI __time_get {
protected:
  __locale::__locale_t __loc_;

  __time_get(const char* __nm);
  __time_get(const string& __nm);
  ~__time_get();
};

template <class _CharT>
class __time_get_storage : public __time_get {
protected:
  typedef basic_string<_CharT> string_type;

  string_type __weeks_[14];
  string_type __months_[24];
  string_type __am_pm_[2];
  string_type __c_;
  string_type __r_;
  string_type __x_;
  string_type __X_;

  explicit __time_get_storage(const char* __nm);
  explicit __time_get_storage(const string& __nm);

  _LIBCPP_HIDE_FROM_ABI ~__time_get_storage() {}

  time_base::dateorder __do_date_order() const;

private:
  void init(const ctype<_CharT>&);
  string_type __analyze(char __fmt, const ctype<_CharT>&);
};

#  define _LIBCPP_TIME_GET_STORAGE_EXPLICIT_INSTANTIATION(_CharT)                                                      \
    template <>                                                                                                        \
    _LIBCPP_EXPORTED_FROM_ABI time_base::dateorder __time_get_storage<_CharT>::__do_date_order() const;                \
    template <>                                                                                                        \
    _LIBCPP_EXPORTED_FROM_ABI __time_get_storage<_CharT>::__time_get_storage(const char*);                             \
    template <>                                                                                                        \
    _LIBCPP_EXPORTED_FROM_ABI __time_get_storage<_CharT>::__time_get_storage(const string&);                           \
    template <>                                                                                                        \
    _LIBCPP_EXPORTED_FROM_ABI void __time_get_storage<_CharT>::init(const ctype<_CharT>&);                             \
    template <>                                                                                                        \
    _LIBCPP_EXPORTED_FROM_ABI __time_get_storage<_CharT>::string_type __time_get_storage<_CharT>::__analyze(           \
        char, const ctype<_CharT>&);                                                                                   \
    extern template _LIBCPP_EXPORTED_FROM_ABI time_base::dateorder __time_get_storage<_CharT>::__do_date_order()       \
        const;                                                                                                         \
    extern template _LIBCPP_EXPORTED_FROM_ABI __time_get_storage<_CharT>::__time_get_storage(const char*);             \
    extern template _LIBCPP_EXPORTED_FROM_ABI __time_get_storage<_CharT>::__time_get_storage(const string&);           \
    extern template _LIBCPP_EXPORTED_FROM_ABI void __time_get_storage<_CharT>::init(const ctype<_CharT>&);             \
    extern template _LIBCPP_EXPORTED_FROM_ABI __time_get_storage<_CharT>::string_type                                  \
    __time_get_storage<_CharT>::__analyze(char, const ctype<_CharT>&);

_LIBCPP_TIME_GET_STORAGE_EXPLICIT_INSTANTIATION(char)
#  if _LIBCPP_HAS_WIDE_CHARACTERS
_LIBCPP_TIME_GET_STORAGE_EXPLICIT_INSTANTIATION(wchar_t)
#  endif
#  undef _LIBCPP_TIME_GET_STORAGE_EXPLICIT_INSTANTIATION

template <class _CharT, class _InputIterator = istreambuf_iterator<_CharT> >
class time_get_byname : public time_get<_CharT, _InputIterator>, private __time_get_storage<_CharT> {
public:
  typedef time_base::dateorder dateorder;
  typedef _InputIterator iter_type;
  typedef _CharT char_type;
  typedef basic_string<char_type> string_type;

  _LIBCPP_HIDE_FROM_ABI explicit time_get_byname(const char* __nm, size_t __refs = 0)
      : time_get<_CharT, _InputIterator>(__refs), __time_get_storage<_CharT>(__nm) {}
  _LIBCPP_HIDE_FROM_ABI explicit time_get_byname(const string& __nm, size_t __refs = 0)
      : time_get<_CharT, _InputIterator>(__refs), __time_get_storage<_CharT>(__nm) {}

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~time_get_byname() override {}

  _LIBCPP_HIDE_FROM_ABI_VIRTUAL dateorder do_date_order() const override { return this->__do_date_order(); }

private:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL const string_type* __weeks() const override { return this->__weeks_; }
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL const string_type* __months() const override { return this->__months_; }
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL const string_type* __am_pm() const override { return this->__am_pm_; }
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL const string_type& __c() const override { return this->__c_; }
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL const string_type& __r() const override { return this->__r_; }
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL const string_type& __x() const override { return this->__x_; }
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL const string_type& __X() const override { return this->__X_; }
};

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS time_get_byname<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS time_get_byname<wchar_t>;
#  endif

class _LIBCPP_EXPORTED_FROM_ABI __time_put {
  __locale::__locale_t __loc_;

protected:
  _LIBCPP_HIDE_FROM_ABI __time_put() : __loc_(_LIBCPP_GET_C_LOCALE) {}
  __time_put(const char* __nm);
  __time_put(const string& __nm);
  ~__time_put();
  void __do_put(char* __nb, char*& __ne, const tm* __tm, char __fmt, char __mod) const;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
  void __do_put(wchar_t* __wb, wchar_t*& __we, const tm* __tm, char __fmt, char __mod) const;
#  endif
};

template <class _CharT, class _OutputIterator = ostreambuf_iterator<_CharT> >
class time_put : public locale::facet, private __time_put {
public:
  typedef _CharT char_type;
  typedef _OutputIterator iter_type;

  _LIBCPP_HIDE_FROM_ABI explicit time_put(size_t __refs = 0) : locale::facet(__refs) {}

  iter_type
  put(iter_type __s, ios_base& __iob, char_type __fl, const tm* __tm, const char_type* __pb, const char_type* __pe)
      const;

  _LIBCPP_HIDE_FROM_ABI iter_type
  put(iter_type __s, ios_base& __iob, char_type __fl, const tm* __tm, char __fmt, char __mod = 0) const {
    return do_put(__s, __iob, __fl, __tm, __fmt, __mod);
  }

  static locale::id id;

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~time_put() override {}
  virtual iter_type do_put(iter_type __s, ios_base&, char_type, const tm* __tm, char __fmt, char __mod) const;

  _LIBCPP_HIDE_FROM_ABI explicit time_put(const char* __nm, size_t __refs) : locale::facet(__refs), __time_put(__nm) {}
  _LIBCPP_HIDE_FROM_ABI explicit time_put(const string& __nm, size_t __refs)
      : locale::facet(__refs), __time_put(__nm) {}
};

template <class _CharT, class _OutputIterator>
locale::id time_put<_CharT, _OutputIterator>::id;

template <class _CharT, class _OutputIterator>
_OutputIterator time_put<_CharT, _OutputIterator>::put(
    iter_type __s, ios_base& __iob, char_type __fl, const tm* __tm, const char_type* __pb, const char_type* __pe)
    const {
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__iob.getloc());
  for (; __pb != __pe; ++__pb) {
    if (__ct.narrow(*__pb, 0) == '%') {
      if (++__pb == __pe) {
        *__s++ = __pb[-1];
        break;
      }
      char __mod = 0;
      char __fmt = __ct.narrow(*__pb, 0);
      if (__fmt == 'E' || __fmt == 'O') {
        if (++__pb == __pe) {
          *__s++ = __pb[-2];
          *__s++ = __pb[-1];
          break;
        }
        __mod = __fmt;
        __fmt = __ct.narrow(*__pb, 0);
      }
      __s = do_put(__s, __iob, __fl, __tm, __fmt, __mod);
    } else
      *__s++ = *__pb;
  }
  return __s;
}

template <class _CharT, class _OutputIterator>
_OutputIterator time_put<_CharT, _OutputIterator>::do_put(
    iter_type __s, ios_base&, char_type, const tm* __tm, char __fmt, char __mod) const {
  char_type __nar[100];
  char_type* __nb = __nar;
  char_type* __ne = __nb + 100;
  __do_put(__nb, __ne, __tm, __fmt, __mod);
  return std::copy(__nb, __ne, __s);
}

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS time_put<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS time_put<wchar_t>;
#  endif

template <class _CharT, class _OutputIterator = ostreambuf_iterator<_CharT> >
class time_put_byname : public time_put<_CharT, _OutputIterator> {
public:
  _LIBCPP_HIDE_FROM_ABI explicit time_put_byname(const char* __nm, size_t __refs = 0)
      : time_put<_CharT, _OutputIterator>(__nm, __refs) {}

  _LIBCPP_HIDE_FROM_ABI explicit time_put_byname(const string& __nm, size_t __refs = 0)
      : time_put<_CharT, _OutputIterator>(__nm, __refs) {}

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~time_put_byname() override {}
};

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS time_put_byname<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS time_put_byname<wchar_t>;
#  endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_HAS_LOCALIZATION

#endif // _LIBCPP___LOCALE_DIR_TIME_H
