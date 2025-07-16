//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___LOCALE_DIR_SCAN_KEYWORD_H
#define _LIBCPP___LOCALE_DIR_SCAN_KEYWORD_H

#include <__config>
#include <__memory/unique_ptr.h>
#include <ios>

#if _LIBCPP_HAS_LOCALIZATION

#  if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#    pragma GCC system_header
#  endif

_LIBCPP_BEGIN_NAMESPACE_STD

// __scan_keyword
// Scans [__b, __e) until a match is found in the basic_strings range
//  [__kb, __ke) or until it can be shown that there is no match in [__kb, __ke).
//  __b will be incremented (visibly), consuming CharT until a match is found
//  or proved to not exist.  A keyword may be "", in which will match anything.
//  If one keyword is a prefix of another, and the next CharT in the input
//  might match another keyword, the algorithm will attempt to find the longest
//  matching keyword.  If the longer matching keyword ends up not matching, then
//  no keyword match is found.  If no keyword match is found, __ke is returned
//  and failbit is set in __err.
//  Else an iterator pointing to the matching keyword is found.  If more than
//  one keyword matches, an iterator to the first matching keyword is returned.
//  If on exit __b == __e, eofbit is set in __err.  If __case_sensitive is false,
//  __ct is used to force to lower case before comparing characters.
//  Examples:
//  Keywords:  "a", "abb"
//  If the input is "a", the first keyword matches and eofbit is set.
//  If the input is "abc", no match is found and "ab" are consumed.
template <class _InputIterator, class _ForwardIterator, class _Ctype>
_LIBCPP_HIDE_FROM_ABI _ForwardIterator __scan_keyword(
    _InputIterator& __b,
    _InputIterator __e,
    _ForwardIterator __kb,
    _ForwardIterator __ke,
    const _Ctype& __ct,
    ios_base::iostate& __err,
    bool __case_sensitive = true) {
  typedef typename iterator_traits<_InputIterator>::value_type _CharT;
  size_t __nkw                       = static_cast<size_t>(std::distance(__kb, __ke));
  const unsigned char __doesnt_match = '\0';
  const unsigned char __might_match  = '\1';
  const unsigned char __does_match   = '\2';
  unsigned char __statbuf[100];
  unsigned char* __status = __statbuf;
  unique_ptr<unsigned char, void (*)(void*)> __stat_hold(nullptr, free);
  if (__nkw > sizeof(__statbuf)) {
    __status = (unsigned char*)malloc(__nkw);
    if (__status == nullptr)
      std::__throw_bad_alloc();
    __stat_hold.reset(__status);
  }
  size_t __n_might_match = __nkw; // At this point, any keyword might match
  size_t __n_does_match  = 0;     // but none of them definitely do
  // Initialize all statuses to __might_match, except for "" keywords are __does_match
  unsigned char* __st = __status;
  for (_ForwardIterator __ky = __kb; __ky != __ke; ++__ky, (void)++__st) {
    if (!__ky->empty())
      *__st = __might_match;
    else {
      *__st = __does_match;
      --__n_might_match;
      ++__n_does_match;
    }
  }
  // While there might be a match, test keywords against the next CharT
  for (size_t __indx = 0; __b != __e && __n_might_match > 0; ++__indx) {
    // Peek at the next CharT but don't consume it
    _CharT __c = *__b;
    if (!__case_sensitive)
      __c = __ct.toupper(__c);
    bool __consume = false;
    // For each keyword which might match, see if the __indx character is __c
    // If a match if found, consume __c
    // If a match is found, and that is the last character in the keyword,
    //    then that keyword matches.
    // If the keyword doesn't match this character, then change the keyword
    //    to doesn't match
    __st = __status;
    for (_ForwardIterator __ky = __kb; __ky != __ke; ++__ky, (void)++__st) {
      if (*__st == __might_match) {
        _CharT __kc = (*__ky)[__indx];
        if (!__case_sensitive)
          __kc = __ct.toupper(__kc);
        if (__c == __kc) {
          __consume = true;
          if (__ky->size() == __indx + 1) {
            *__st = __does_match;
            --__n_might_match;
            ++__n_does_match;
          }
        } else {
          *__st = __doesnt_match;
          --__n_might_match;
        }
      }
    }
    // consume if we matched a character
    if (__consume) {
      ++__b;
      // If we consumed a character and there might be a matched keyword that
      //   was marked matched on a previous iteration, then such keywords
      //   which are now marked as not matching.
      if (__n_might_match + __n_does_match > 1) {
        __st = __status;
        for (_ForwardIterator __ky = __kb; __ky != __ke; ++__ky, (void)++__st) {
          if (*__st == __does_match && __ky->size() != __indx + 1) {
            *__st = __doesnt_match;
            --__n_does_match;
          }
        }
      }
    }
  }
  // We've exited the loop because we hit eof and/or we have no more "might matches".
  if (__b == __e)
    __err |= ios_base::eofbit;
  // Return the first matching result
  for (__st = __status; __kb != __ke; ++__kb, (void)++__st)
    if (*__st == __does_match)
      break;
  if (__kb == __ke)
    __err |= ios_base::failbit;
  return __kb;
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_HAS_LOCALIZATION

#endif // _LIBCPP___LOCALE_DIR_SCAN_KEYWORD_H
