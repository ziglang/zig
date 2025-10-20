//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___LOCALE_DIR_MONEY_H
#define _LIBCPP___LOCALE_DIR_MONEY_H

#include <__algorithm/copy.h>
#include <__algorithm/equal.h>
#include <__algorithm/find.h>
#include <__algorithm/reverse.h>
#include <__config>
#include <__locale>
#include <__locale_dir/check_grouping.h>
#include <__locale_dir/get_c_locale.h>
#include <__locale_dir/pad_and_output.h>
#include <__memory/unique_ptr.h>
#include <ios>
#include <string>

#if _LIBCPP_HAS_LOCALIZATION

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

_LIBCPP_PUSH_MACROS
#  include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

// money_base

class _LIBCPP_EXPORTED_FROM_ABI money_base {
public:
  enum part { none, space, symbol, sign, value };
  struct pattern {
    char field[4];
  };

  _LIBCPP_HIDE_FROM_ABI money_base() {}
};

// moneypunct

template <class _CharT, bool _International = false>
class moneypunct : public locale::facet, public money_base {
public:
  typedef _CharT char_type;
  typedef basic_string<char_type> string_type;

  _LIBCPP_HIDE_FROM_ABI explicit moneypunct(size_t __refs = 0) : locale::facet(__refs) {}

  _LIBCPP_HIDE_FROM_ABI char_type decimal_point() const { return do_decimal_point(); }
  _LIBCPP_HIDE_FROM_ABI char_type thousands_sep() const { return do_thousands_sep(); }
  _LIBCPP_HIDE_FROM_ABI string grouping() const { return do_grouping(); }
  _LIBCPP_HIDE_FROM_ABI string_type curr_symbol() const { return do_curr_symbol(); }
  _LIBCPP_HIDE_FROM_ABI string_type positive_sign() const { return do_positive_sign(); }
  _LIBCPP_HIDE_FROM_ABI string_type negative_sign() const { return do_negative_sign(); }
  _LIBCPP_HIDE_FROM_ABI int frac_digits() const { return do_frac_digits(); }
  _LIBCPP_HIDE_FROM_ABI pattern pos_format() const { return do_pos_format(); }
  _LIBCPP_HIDE_FROM_ABI pattern neg_format() const { return do_neg_format(); }

  static locale::id id;
  static const bool intl = _International;

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~moneypunct() override {}

  virtual char_type do_decimal_point() const { return numeric_limits<char_type>::max(); }
  virtual char_type do_thousands_sep() const { return numeric_limits<char_type>::max(); }
  virtual string do_grouping() const { return string(); }
  virtual string_type do_curr_symbol() const { return string_type(); }
  virtual string_type do_positive_sign() const { return string_type(); }
  virtual string_type do_negative_sign() const { return string_type(1, '-'); }
  virtual int do_frac_digits() const { return 0; }
  virtual pattern do_pos_format() const {
    pattern __p = {{symbol, sign, none, value}};
    return __p;
  }
  virtual pattern do_neg_format() const {
    pattern __p = {{symbol, sign, none, value}};
    return __p;
  }
};

template <class _CharT, bool _International>
locale::id moneypunct<_CharT, _International>::id;

template <class _CharT, bool _International>
const bool moneypunct<_CharT, _International>::intl;

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS moneypunct<char, false>;
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS moneypunct<char, true>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS moneypunct<wchar_t, false>;
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS moneypunct<wchar_t, true>;
#  endif

// moneypunct_byname

template <class _CharT, bool _International = false>
class moneypunct_byname : public moneypunct<_CharT, _International> {
public:
  typedef money_base::pattern pattern;
  typedef _CharT char_type;
  typedef basic_string<char_type> string_type;

  _LIBCPP_HIDE_FROM_ABI explicit moneypunct_byname(const char* __nm, size_t __refs = 0)
      : moneypunct<_CharT, _International>(__refs) {
    init(__nm);
  }

  _LIBCPP_HIDE_FROM_ABI explicit moneypunct_byname(const string& __nm, size_t __refs = 0)
      : moneypunct<_CharT, _International>(__refs) {
    init(__nm.c_str());
  }

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~moneypunct_byname() override {}

  char_type do_decimal_point() const override { return __decimal_point_; }
  char_type do_thousands_sep() const override { return __thousands_sep_; }
  string do_grouping() const override { return __grouping_; }
  string_type do_curr_symbol() const override { return __curr_symbol_; }
  string_type do_positive_sign() const override { return __positive_sign_; }
  string_type do_negative_sign() const override { return __negative_sign_; }
  int do_frac_digits() const override { return __frac_digits_; }
  pattern do_pos_format() const override { return __pos_format_; }
  pattern do_neg_format() const override { return __neg_format_; }

private:
  char_type __decimal_point_;
  char_type __thousands_sep_;
  string __grouping_;
  string_type __curr_symbol_;
  string_type __positive_sign_;
  string_type __negative_sign_;
  int __frac_digits_;
  pattern __pos_format_;
  pattern __neg_format_;

  void init(const char*);
};

template <>
_LIBCPP_EXPORTED_FROM_ABI void moneypunct_byname<char, false>::init(const char*);
template <>
_LIBCPP_EXPORTED_FROM_ABI void moneypunct_byname<char, true>::init(const char*);
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS moneypunct_byname<char, false>;
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS moneypunct_byname<char, true>;

#  if _LIBCPP_HAS_WIDE_CHARACTERS
template <>
_LIBCPP_EXPORTED_FROM_ABI void moneypunct_byname<wchar_t, false>::init(const char*);
template <>
_LIBCPP_EXPORTED_FROM_ABI void moneypunct_byname<wchar_t, true>::init(const char*);
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS moneypunct_byname<wchar_t, false>;
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS moneypunct_byname<wchar_t, true>;
#  endif

// money_get

template <class _CharT>
class __money_get {
protected:
  typedef _CharT char_type;
  typedef basic_string<char_type> string_type;

  _LIBCPP_HIDE_FROM_ABI __money_get() {}

  static void __gather_info(
      bool __intl,
      const locale& __loc,
      money_base::pattern& __pat,
      char_type& __dp,
      char_type& __ts,
      string& __grp,
      string_type& __sym,
      string_type& __psn,
      string_type& __nsn,
      int& __fd);
};

template <class _CharT>
void __money_get<_CharT>::__gather_info(
    bool __intl,
    const locale& __loc,
    money_base::pattern& __pat,
    char_type& __dp,
    char_type& __ts,
    string& __grp,
    string_type& __sym,
    string_type& __psn,
    string_type& __nsn,
    int& __fd) {
  if (__intl) {
    const moneypunct<char_type, true>& __mp = std::use_facet<moneypunct<char_type, true> >(__loc);
    __pat                                   = __mp.neg_format();
    __nsn                                   = __mp.negative_sign();
    __psn                                   = __mp.positive_sign();
    __dp                                    = __mp.decimal_point();
    __ts                                    = __mp.thousands_sep();
    __grp                                   = __mp.grouping();
    __sym                                   = __mp.curr_symbol();
    __fd                                    = __mp.frac_digits();
  } else {
    const moneypunct<char_type, false>& __mp = std::use_facet<moneypunct<char_type, false> >(__loc);
    __pat                                    = __mp.neg_format();
    __nsn                                    = __mp.negative_sign();
    __psn                                    = __mp.positive_sign();
    __dp                                     = __mp.decimal_point();
    __ts                                     = __mp.thousands_sep();
    __grp                                    = __mp.grouping();
    __sym                                    = __mp.curr_symbol();
    __fd                                     = __mp.frac_digits();
  }
}

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS __money_get<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS __money_get<wchar_t>;
#  endif

template <class _CharT, class _InputIterator = istreambuf_iterator<_CharT> >
class money_get : public locale::facet, private __money_get<_CharT> {
public:
  typedef _CharT char_type;
  typedef _InputIterator iter_type;
  typedef basic_string<char_type> string_type;

  _LIBCPP_HIDE_FROM_ABI explicit money_get(size_t __refs = 0) : locale::facet(__refs) {}

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, bool __intl, ios_base& __iob, ios_base::iostate& __err, long double& __v) const {
    return do_get(__b, __e, __intl, __iob, __err, __v);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  get(iter_type __b, iter_type __e, bool __intl, ios_base& __iob, ios_base::iostate& __err, string_type& __v) const {
    return do_get(__b, __e, __intl, __iob, __err, __v);
  }

  static locale::id id;

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~money_get() override {}

  virtual iter_type
  do_get(iter_type __b, iter_type __e, bool __intl, ios_base& __iob, ios_base::iostate& __err, long double& __v) const;
  virtual iter_type
  do_get(iter_type __b, iter_type __e, bool __intl, ios_base& __iob, ios_base::iostate& __err, string_type& __v) const;

private:
  static bool __do_get(
      iter_type& __b,
      iter_type __e,
      bool __intl,
      const locale& __loc,
      ios_base::fmtflags __flags,
      ios_base::iostate& __err,
      bool& __neg,
      const ctype<char_type>& __ct,
      unique_ptr<char_type, void (*)(void*)>& __wb,
      char_type*& __wn,
      char_type* __we);
};

template <class _CharT, class _InputIterator>
locale::id money_get<_CharT, _InputIterator>::id;

_LIBCPP_EXPORTED_FROM_ABI void __do_nothing(void*);

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI void __double_or_nothing(unique_ptr<_Tp, void (*)(void*)>& __b, _Tp*& __n, _Tp*& __e) {
  bool __owns      = __b.get_deleter() != __do_nothing;
  size_t __cur_cap = static_cast<size_t>(__e - __b.get()) * sizeof(_Tp);
  size_t __new_cap = __cur_cap < numeric_limits<size_t>::max() / 2 ? 2 * __cur_cap : numeric_limits<size_t>::max();
  if (__new_cap == 0)
    __new_cap = sizeof(_Tp);
  size_t __n_off = static_cast<size_t>(__n - __b.get());
  _Tp* __t       = (_Tp*)std::realloc(__owns ? __b.get() : 0, __new_cap);
  if (__t == 0)
    std::__throw_bad_alloc();
  if (__owns)
    __b.release();
  else
    std::memcpy(__t, __b.get(), __cur_cap);
  __b = unique_ptr<_Tp, void (*)(void*)>(__t, free);
  __new_cap /= sizeof(_Tp);
  __n = __b.get() + __n_off;
  __e = __b.get() + __new_cap;
}

// true == success
template <class _CharT, class _InputIterator>
bool money_get<_CharT, _InputIterator>::__do_get(
    iter_type& __b,
    iter_type __e,
    bool __intl,
    const locale& __loc,
    ios_base::fmtflags __flags,
    ios_base::iostate& __err,
    bool& __neg,
    const ctype<char_type>& __ct,
    unique_ptr<char_type, void (*)(void*)>& __wb,
    char_type*& __wn,
    char_type* __we) {
  if (__b == __e) {
    __err |= ios_base::failbit;
    return false;
  }
  const unsigned __bz = 100;
  unsigned __gbuf[__bz];
  unique_ptr<unsigned, void (*)(void*)> __gb(__gbuf, __do_nothing);
  unsigned* __gn = __gb.get();
  unsigned* __ge = __gn + __bz;
  money_base::pattern __pat;
  char_type __dp;
  char_type __ts;
  string __grp;
  string_type __sym;
  string_type __psn;
  string_type __nsn;
  // Capture the spaces read into money_base::{space,none} so they
  // can be compared to initial spaces in __sym.
  string_type __spaces;
  int __fd;
  __money_get<_CharT>::__gather_info(__intl, __loc, __pat, __dp, __ts, __grp, __sym, __psn, __nsn, __fd);
  const string_type* __trailing_sign = 0;
  __wn                               = __wb.get();
  for (unsigned __p = 0; __p < 4 && __b != __e; ++__p) {
    switch (__pat.field[__p]) {
    case money_base::space:
      if (__p != 3) {
        if (__ct.is(ctype_base::space, *__b))
          __spaces.push_back(*__b++);
        else {
          __err |= ios_base::failbit;
          return false;
        }
      }
      [[__fallthrough__]];
    case money_base::none:
      if (__p != 3) {
        while (__b != __e && __ct.is(ctype_base::space, *__b))
          __spaces.push_back(*__b++);
      }
      break;
    case money_base::sign:
      if (__psn.size() > 0 && *__b == __psn[0]) {
        ++__b;
        __neg = false;
        if (__psn.size() > 1)
          __trailing_sign = std::addressof(__psn);
        break;
      }
      if (__nsn.size() > 0 && *__b == __nsn[0]) {
        ++__b;
        __neg = true;
        if (__nsn.size() > 1)
          __trailing_sign = std::addressof(__nsn);
        break;
      }
      if (__psn.size() > 0 && __nsn.size() > 0) { // sign is required
        __err |= ios_base::failbit;
        return false;
      }
      if (__psn.size() == 0 && __nsn.size() == 0)
        // locale has no way of specifying a sign. Use the initial value of __neg as a default
        break;
      __neg = (__nsn.size() == 0);
      break;
    case money_base::symbol: {
      bool __more_needed =
          __trailing_sign || (__p < 2) || (__p == 2 && __pat.field[3] != static_cast<char>(money_base::none));
      bool __sb = (__flags & ios_base::showbase) != 0;
      if (__sb || __more_needed) {
        typename string_type::const_iterator __sym_space_end = __sym.begin();
        if (__p > 0 && (__pat.field[__p - 1] == money_base::none || __pat.field[__p - 1] == money_base::space)) {
          // Match spaces we've already read against spaces at
          // the beginning of __sym.
          while (__sym_space_end != __sym.end() && __ct.is(ctype_base::space, *__sym_space_end))
            ++__sym_space_end;
          const size_t __num_spaces = __sym_space_end - __sym.begin();
          if (__num_spaces > __spaces.size() ||
              !std::equal(__spaces.end() - __num_spaces, __spaces.end(), __sym.begin())) {
            // No match. Put __sym_space_end back at the
            // beginning of __sym, which will prevent a
            // match in the next loop.
            __sym_space_end = __sym.begin();
          }
        }
        typename string_type::const_iterator __sym_curr_char = __sym_space_end;
        while (__sym_curr_char != __sym.end() && __b != __e && *__b == *__sym_curr_char) {
          ++__b;
          ++__sym_curr_char;
        }
        if (__sb && __sym_curr_char != __sym.end()) {
          __err |= ios_base::failbit;
          return false;
        }
      }
    } break;
    case money_base::value: {
      unsigned __ng = 0;
      for (; __b != __e; ++__b) {
        char_type __c = *__b;
        if (__ct.is(ctype_base::digit, __c)) {
          if (__wn == __we)
            std::__double_or_nothing(__wb, __wn, __we);
          *__wn++ = __c;
          ++__ng;
        } else if (__grp.size() > 0 && __ng > 0 && __c == __ts) {
          if (__gn == __ge)
            std::__double_or_nothing(__gb, __gn, __ge);
          *__gn++ = __ng;
          __ng    = 0;
        } else
          break;
      }
      if (__gb.get() != __gn && __ng > 0) {
        if (__gn == __ge)
          std::__double_or_nothing(__gb, __gn, __ge);
        *__gn++ = __ng;
      }
      if (__fd > 0) {
        if (__b == __e || *__b != __dp) {
          __err |= ios_base::failbit;
          return false;
        }
        for (++__b; __fd > 0; --__fd, ++__b) {
          if (__b == __e || !__ct.is(ctype_base::digit, *__b)) {
            __err |= ios_base::failbit;
            return false;
          }
          if (__wn == __we)
            std::__double_or_nothing(__wb, __wn, __we);
          *__wn++ = *__b;
        }
      }
      if (__wn == __wb.get()) {
        __err |= ios_base::failbit;
        return false;
      }
    } break;
    }
  }
  if (__trailing_sign) {
    for (unsigned __i = 1; __i < __trailing_sign->size(); ++__i, ++__b) {
      if (__b == __e || *__b != (*__trailing_sign)[__i]) {
        __err |= ios_base::failbit;
        return false;
      }
    }
  }
  if (__gb.get() != __gn) {
    ios_base::iostate __et = ios_base::goodbit;
    __check_grouping(__grp, __gb.get(), __gn, __et);
    if (__et) {
      __err |= ios_base::failbit;
      return false;
    }
  }
  return true;
}

template <class _CharT, class _InputIterator>
_InputIterator money_get<_CharT, _InputIterator>::do_get(
    iter_type __b, iter_type __e, bool __intl, ios_base& __iob, ios_base::iostate& __err, long double& __v) const {
  const int __bz = 100;
  char_type __wbuf[__bz];
  unique_ptr<char_type, void (*)(void*)> __wb(__wbuf, __do_nothing);
  char_type* __wn;
  char_type* __we              = __wbuf + __bz;
  locale __loc                 = __iob.getloc();
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__loc);
  bool __neg                   = false;
  if (__do_get(__b, __e, __intl, __loc, __iob.flags(), __err, __neg, __ct, __wb, __wn, __we)) {
    const char __src[] = "0123456789";
    char_type __atoms[sizeof(__src) - 1];
    __ct.widen(__src, __src + (sizeof(__src) - 1), __atoms);
    char __nbuf[__bz];
    char* __nc          = __nbuf;
    const char* __nc_in = __nc;
    unique_ptr<char, void (*)(void*)> __h(nullptr, free);
    if (__wn - __wb.get() > __bz - 2) {
      __h.reset((char*)malloc(static_cast<size_t>(__wn - __wb.get() + 2)));
      if (__h.get() == nullptr)
        std::__throw_bad_alloc();
      __nc    = __h.get();
      __nc_in = __nc;
    }
    if (__neg)
      *__nc++ = '-';
    for (const char_type* __w = __wb.get(); __w < __wn; ++__w, ++__nc)
      *__nc = __src[std::find(__atoms, std::end(__atoms), *__w) - __atoms];
    *__nc = char();
    if (sscanf(__nc_in, "%Lf", &__v) != 1)
      std::__throw_runtime_error("money_get error");
  }
  if (__b == __e)
    __err |= ios_base::eofbit;
  return __b;
}

template <class _CharT, class _InputIterator>
_InputIterator money_get<_CharT, _InputIterator>::do_get(
    iter_type __b, iter_type __e, bool __intl, ios_base& __iob, ios_base::iostate& __err, string_type& __v) const {
  const int __bz = 100;
  char_type __wbuf[__bz];
  unique_ptr<char_type, void (*)(void*)> __wb(__wbuf, __do_nothing);
  char_type* __wn;
  char_type* __we              = __wbuf + __bz;
  locale __loc                 = __iob.getloc();
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__loc);
  bool __neg                   = false;
  if (__do_get(__b, __e, __intl, __loc, __iob.flags(), __err, __neg, __ct, __wb, __wn, __we)) {
    __v.clear();
    if (__neg)
      __v.push_back(__ct.widen('-'));
    char_type __z = __ct.widen('0');
    char_type* __w;
    for (__w = __wb.get(); __w < __wn - 1; ++__w)
      if (*__w != __z)
        break;
    __v.append(__w, __wn);
  }
  if (__b == __e)
    __err |= ios_base::eofbit;
  return __b;
}

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS money_get<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS money_get<wchar_t>;
#  endif

// money_put

template <class _CharT>
class __money_put {
protected:
  typedef _CharT char_type;
  typedef basic_string<char_type> string_type;

  _LIBCPP_HIDE_FROM_ABI __money_put() {}

  static void __gather_info(
      bool __intl,
      bool __neg,
      const locale& __loc,
      money_base::pattern& __pat,
      char_type& __dp,
      char_type& __ts,
      string& __grp,
      string_type& __sym,
      string_type& __sn,
      int& __fd);
  static void __format(
      char_type* __mb,
      char_type*& __mi,
      char_type*& __me,
      ios_base::fmtflags __flags,
      const char_type* __db,
      const char_type* __de,
      const ctype<char_type>& __ct,
      bool __neg,
      const money_base::pattern& __pat,
      char_type __dp,
      char_type __ts,
      const string& __grp,
      const string_type& __sym,
      const string_type& __sn,
      int __fd);
};

template <class _CharT>
void __money_put<_CharT>::__gather_info(
    bool __intl,
    bool __neg,
    const locale& __loc,
    money_base::pattern& __pat,
    char_type& __dp,
    char_type& __ts,
    string& __grp,
    string_type& __sym,
    string_type& __sn,
    int& __fd) {
  if (__intl) {
    const moneypunct<char_type, true>& __mp = std::use_facet<moneypunct<char_type, true> >(__loc);
    if (__neg) {
      __pat = __mp.neg_format();
      __sn  = __mp.negative_sign();
    } else {
      __pat = __mp.pos_format();
      __sn  = __mp.positive_sign();
    }
    __dp  = __mp.decimal_point();
    __ts  = __mp.thousands_sep();
    __grp = __mp.grouping();
    __sym = __mp.curr_symbol();
    __fd  = __mp.frac_digits();
  } else {
    const moneypunct<char_type, false>& __mp = std::use_facet<moneypunct<char_type, false> >(__loc);
    if (__neg) {
      __pat = __mp.neg_format();
      __sn  = __mp.negative_sign();
    } else {
      __pat = __mp.pos_format();
      __sn  = __mp.positive_sign();
    }
    __dp  = __mp.decimal_point();
    __ts  = __mp.thousands_sep();
    __grp = __mp.grouping();
    __sym = __mp.curr_symbol();
    __fd  = __mp.frac_digits();
  }
}

template <class _CharT>
void __money_put<_CharT>::__format(
    char_type* __mb,
    char_type*& __mi,
    char_type*& __me,
    ios_base::fmtflags __flags,
    const char_type* __db,
    const char_type* __de,
    const ctype<char_type>& __ct,
    bool __neg,
    const money_base::pattern& __pat,
    char_type __dp,
    char_type __ts,
    const string& __grp,
    const string_type& __sym,
    const string_type& __sn,
    int __fd) {
  __me = __mb;
  for (char __p : __pat.field) {
    switch (__p) {
    case money_base::none:
      __mi = __me;
      break;
    case money_base::space:
      __mi    = __me;
      *__me++ = __ct.widen(' ');
      break;
    case money_base::sign:
      if (!__sn.empty())
        *__me++ = __sn[0];
      break;
    case money_base::symbol:
      if (!__sym.empty() && (__flags & ios_base::showbase))
        __me = std::copy(__sym.begin(), __sym.end(), __me);
      break;
    case money_base::value: {
      // remember start of value so we can reverse it
      char_type* __t = __me;
      // find beginning of digits
      if (__neg)
        ++__db;
      // find end of digits
      const char_type* __d;
      for (__d = __db; __d < __de; ++__d)
        if (!__ct.is(ctype_base::digit, *__d))
          break;
      // print fractional part
      if (__fd > 0) {
        int __f;
        for (__f = __fd; __d > __db && __f > 0; --__f)
          *__me++ = *--__d;
        char_type __z = __f > 0 ? __ct.widen('0') : char_type();
        for (; __f > 0; --__f)
          *__me++ = __z;
        *__me++ = __dp;
      }
      // print units part
      if (__d == __db) {
        *__me++ = __ct.widen('0');
      } else {
        unsigned __ng = 0;
        unsigned __ig = 0;
        unsigned __gl = __grp.empty() ? numeric_limits<unsigned>::max() : static_cast<unsigned>(__grp[__ig]);
        while (__d != __db) {
          if (__ng == __gl) {
            *__me++ = __ts;
            __ng    = 0;
            if (++__ig < __grp.size())
              __gl = __grp[__ig] == numeric_limits<char>::max()
                       ? numeric_limits<unsigned>::max()
                       : static_cast<unsigned>(__grp[__ig]);
          }
          *__me++ = *--__d;
          ++__ng;
        }
      }
      // reverse it
      std::reverse(__t, __me);
    } break;
    }
  }
  // print rest of sign, if any
  if (__sn.size() > 1)
    __me = std::copy(__sn.begin() + 1, __sn.end(), __me);
  // set alignment
  if ((__flags & ios_base::adjustfield) == ios_base::left)
    __mi = __me;
  else if ((__flags & ios_base::adjustfield) != ios_base::internal)
    __mi = __mb;
}

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS __money_put<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS __money_put<wchar_t>;
#  endif

template <class _CharT, class _OutputIterator = ostreambuf_iterator<_CharT> >
class money_put : public locale::facet, private __money_put<_CharT> {
public:
  typedef _CharT char_type;
  typedef _OutputIterator iter_type;
  typedef basic_string<char_type> string_type;

  _LIBCPP_HIDE_FROM_ABI explicit money_put(size_t __refs = 0) : locale::facet(__refs) {}

  _LIBCPP_HIDE_FROM_ABI iter_type
  put(iter_type __s, bool __intl, ios_base& __iob, char_type __fl, long double __units) const {
    return do_put(__s, __intl, __iob, __fl, __units);
  }

  _LIBCPP_HIDE_FROM_ABI iter_type
  put(iter_type __s, bool __intl, ios_base& __iob, char_type __fl, const string_type& __digits) const {
    return do_put(__s, __intl, __iob, __fl, __digits);
  }

  static locale::id id;

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~money_put() override {}

  virtual iter_type do_put(iter_type __s, bool __intl, ios_base& __iob, char_type __fl, long double __units) const;
  virtual iter_type
  do_put(iter_type __s, bool __intl, ios_base& __iob, char_type __fl, const string_type& __digits) const;
};

template <class _CharT, class _OutputIterator>
locale::id money_put<_CharT, _OutputIterator>::id;

template <class _CharT, class _OutputIterator>
_OutputIterator money_put<_CharT, _OutputIterator>::do_put(
    iter_type __s, bool __intl, ios_base& __iob, char_type __fl, long double __units) const {
  // convert to char
  const size_t __bs = 100;
  char __buf[__bs];
  char* __bb = __buf;
  char_type __digits[__bs];
  char_type* __db = __digits;
  int __n         = snprintf(__bb, __bs, "%.0Lf", __units);
  unique_ptr<char, void (*)(void*)> __hn(nullptr, free);
  unique_ptr<char_type, void (*)(void*)> __hd(0, free);
  // secure memory for digit storage
  if (static_cast<size_t>(__n) > __bs - 1) {
    __n = __locale::__asprintf(&__bb, _LIBCPP_GET_C_LOCALE, "%.0Lf", __units);
    if (__n == -1)
      std::__throw_bad_alloc();
    __hn.reset(__bb);
    __hd.reset((char_type*)malloc(static_cast<size_t>(__n) * sizeof(char_type)));
    if (__hd == nullptr)
      std::__throw_bad_alloc();
    __db = __hd.get();
  }
  // gather info
  locale __loc                 = __iob.getloc();
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__loc);
  __ct.widen(__bb, __bb + __n, __db);
  bool __neg = __n > 0 && __bb[0] == '-';
  money_base::pattern __pat;
  char_type __dp;
  char_type __ts;
  string __grp;
  string_type __sym;
  string_type __sn;
  int __fd;
  this->__gather_info(__intl, __neg, __loc, __pat, __dp, __ts, __grp, __sym, __sn, __fd);
  // secure memory for formatting
  char_type __mbuf[__bs];
  char_type* __mb = __mbuf;
  unique_ptr<char_type, void (*)(void*)> __hw(0, free);
  size_t __exn = __n > __fd ? (static_cast<size_t>(__n) - static_cast<size_t>(__fd)) * 2 + __sn.size() + __sym.size() +
                                  static_cast<size_t>(__fd) + 1
                            : __sn.size() + __sym.size() + static_cast<size_t>(__fd) + 2;
  if (__exn > __bs) {
    __hw.reset((char_type*)malloc(__exn * sizeof(char_type)));
    __mb = __hw.get();
    if (__mb == 0)
      std::__throw_bad_alloc();
  }
  // format
  char_type* __mi;
  char_type* __me;
  this->__format(
      __mb, __mi, __me, __iob.flags(), __db, __db + __n, __ct, __neg, __pat, __dp, __ts, __grp, __sym, __sn, __fd);
  return std::__pad_and_output(__s, __mb, __mi, __me, __iob, __fl);
}

template <class _CharT, class _OutputIterator>
_OutputIterator money_put<_CharT, _OutputIterator>::do_put(
    iter_type __s, bool __intl, ios_base& __iob, char_type __fl, const string_type& __digits) const {
  // gather info
  locale __loc                 = __iob.getloc();
  const ctype<char_type>& __ct = std::use_facet<ctype<char_type> >(__loc);
  bool __neg                   = __digits.size() > 0 && __digits[0] == __ct.widen('-');
  money_base::pattern __pat;
  char_type __dp;
  char_type __ts;
  string __grp;
  string_type __sym;
  string_type __sn;
  int __fd;
  this->__gather_info(__intl, __neg, __loc, __pat, __dp, __ts, __grp, __sym, __sn, __fd);
  // secure memory for formatting
  char_type __mbuf[100];
  char_type* __mb = __mbuf;
  unique_ptr<char_type, void (*)(void*)> __h(0, free);
  size_t __exn =
      static_cast<int>(__digits.size()) > __fd
          ? (__digits.size() - static_cast<size_t>(__fd)) * 2 + __sn.size() + __sym.size() + static_cast<size_t>(__fd) +
                1
          : __sn.size() + __sym.size() + static_cast<size_t>(__fd) + 2;
  if (__exn > 100) {
    __h.reset((char_type*)malloc(__exn * sizeof(char_type)));
    __mb = __h.get();
    if (__mb == 0)
      std::__throw_bad_alloc();
  }
  // format
  char_type* __mi;
  char_type* __me;
  this->__format(
      __mb,
      __mi,
      __me,
      __iob.flags(),
      __digits.data(),
      __digits.data() + __digits.size(),
      __ct,
      __neg,
      __pat,
      __dp,
      __ts,
      __grp,
      __sym,
      __sn,
      __fd);
  return std::__pad_and_output(__s, __mb, __mi, __me, __iob, __fl);
}

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS money_put<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS money_put<wchar_t>;
#  endif

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP_HAS_LOCALIZATION

#endif // _LIBCPP___LOCALE_DIR_MONEY_H
