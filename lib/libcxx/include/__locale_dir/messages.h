//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___LOCALE_DIR_MESSAGES_H
#define _LIBCPP___LOCALE_DIR_MESSAGES_H

#include <__config>
#include <__iterator/back_insert_iterator.h>
#include <__locale>
#include <string>

#if _LIBCPP_HAS_LOCALIZATION

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

#  if defined(__unix__) || (defined(__APPLE__) && defined(__MACH__))
// Most unix variants have catopen.  These are the specific ones that don't.
#    if !defined(__BIONIC__) && !defined(_NEWLIB_VERSION) && !defined(__EMSCRIPTEN__)
#      define _LIBCPP_HAS_CATOPEN 1
#      include <nl_types.h>
#    else
#      define _LIBCPP_HAS_CATOPEN 0
#    endif
#  else
#    define _LIBCPP_HAS_CATOPEN 0
#  endif

_LIBCPP_BEGIN_NAMESPACE_STD

class _LIBCPP_EXPORTED_FROM_ABI messages_base {
public:
  typedef intptr_t catalog;

  _LIBCPP_HIDE_FROM_ABI messages_base() {}
};

template <class _CharT>
class messages : public locale::facet, public messages_base {
public:
  typedef _CharT char_type;
  typedef basic_string<_CharT> string_type;

  _LIBCPP_HIDE_FROM_ABI explicit messages(size_t __refs = 0) : locale::facet(__refs) {}

  _LIBCPP_HIDE_FROM_ABI catalog open(const basic_string<char>& __nm, const locale& __loc) const {
    return do_open(__nm, __loc);
  }

  _LIBCPP_HIDE_FROM_ABI string_type get(catalog __c, int __set, int __msgid, const string_type& __dflt) const {
    return do_get(__c, __set, __msgid, __dflt);
  }

  _LIBCPP_HIDE_FROM_ABI void close(catalog __c) const { do_close(__c); }

  static locale::id id;

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~messages() override {}

  virtual catalog do_open(const basic_string<char>&, const locale&) const;
  virtual string_type do_get(catalog, int __set, int __msgid, const string_type& __dflt) const;
  virtual void do_close(catalog) const;
};

template <class _CharT>
locale::id messages<_CharT>::id;

template <class _CharT>
typename messages<_CharT>::catalog messages<_CharT>::do_open(const basic_string<char>& __nm, const locale&) const {
#  if _LIBCPP_HAS_CATOPEN
  return (catalog)catopen(__nm.c_str(), NL_CAT_LOCALE);
#  else  // !_LIBCPP_HAS_CATOPEN
  (void)__nm;
  return -1;
#  endif // _LIBCPP_HAS_CATOPEN
}

template <class _CharT>
typename messages<_CharT>::string_type
messages<_CharT>::do_get(catalog __c, int __set, int __msgid, const string_type& __dflt) const {
#  if _LIBCPP_HAS_CATOPEN
  string __ndflt;
  __narrow_to_utf8<sizeof(char_type) * __CHAR_BIT__>()(
      std::back_inserter(__ndflt), __dflt.c_str(), __dflt.c_str() + __dflt.size());
  nl_catd __cat = (nl_catd)__c;
  static_assert(sizeof(catalog) >= sizeof(nl_catd), "Unexpected nl_catd type");
  char* __n = catgets(__cat, __set, __msgid, __ndflt.c_str());
  string_type __w;
  __widen_from_utf8<sizeof(char_type) * __CHAR_BIT__>()(std::back_inserter(__w), __n, __n + std::strlen(__n));
  return __w;
#  else  // !_LIBCPP_HAS_CATOPEN
  (void)__c;
  (void)__set;
  (void)__msgid;
  return __dflt;
#  endif // _LIBCPP_HAS_CATOPEN
}

template <class _CharT>
void messages<_CharT>::do_close(catalog __c) const {
#  if _LIBCPP_HAS_CATOPEN
  catclose((nl_catd)__c);
#  else  // !_LIBCPP_HAS_CATOPEN
  (void)__c;
#  endif // _LIBCPP_HAS_CATOPEN
}

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS messages<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS messages<wchar_t>;
#  endif

template <class _CharT>
class messages_byname : public messages<_CharT> {
public:
  typedef messages_base::catalog catalog;
  typedef basic_string<_CharT> string_type;

  _LIBCPP_HIDE_FROM_ABI explicit messages_byname(const char*, size_t __refs = 0) : messages<_CharT>(__refs) {}

  _LIBCPP_HIDE_FROM_ABI explicit messages_byname(const string&, size_t __refs = 0) : messages<_CharT>(__refs) {}

protected:
  _LIBCPP_HIDE_FROM_ABI_VIRTUAL ~messages_byname() override {}
};

extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS messages_byname<char>;
#  if _LIBCPP_HAS_WIDE_CHARACTERS
extern template class _LIBCPP_EXTERN_TEMPLATE_TYPE_VIS messages_byname<wchar_t>;
#  endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_HAS_LOCALIZATION

#endif // _LIBCPP___LOCALE_DIR_MESSAGES_H
