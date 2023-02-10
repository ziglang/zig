// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_UNICODE_H
#define _LIBCPP___FORMAT_UNICODE_H

#include <__assert>
#include <__config>
#include <__format/extended_grapheme_cluster_table.h>
#include <__utility/unreachable.h>
#include <bit>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

#  ifndef _LIBCPP_HAS_NO_UNICODE

/// Implements the grapheme cluster boundary rules
///
/// These rules are used to implement format's width estimation as stated in
/// [format.string.std]/11
///
/// The Standard refers to UAX \#29 for Unicode 12.0.0
/// https://www.unicode.org/reports/tr29/#Grapheme_Cluster_Boundary_Rules
///
/// The data tables used are
/// https://www.unicode.org/Public/UCD/latest/ucd/auxiliary/GraphemeBreakProperty.txt
/// https://www.unicode.org/Public/UCD/latest/ucd/emoji/emoji-data.txt
/// https://www.unicode.org/Public/UCD/latest/ucd/auxiliary/GraphemeBreakTest.txt (for testing only)

namespace __unicode {

inline constexpr char32_t __replacement_character = U'\ufffd';

_LIBCPP_HIDE_FROM_ABI constexpr bool __is_continuation(const char* __char, int __count) {
  do {
    if ((*__char & 0b1000'0000) != 0b1000'0000)
      return false;
    --__count;
    ++__char;
  } while (__count);
  return true;
}

/// Helper class to extract a code unit from a Unicode character range.
///
/// The stored range is a view. There are multiple specialization for different
/// character types.
template <class _CharT>
class __code_point_view;

/// UTF-8 specialization.
template <>
class __code_point_view<char> {
public:
  _LIBCPP_HIDE_FROM_ABI constexpr explicit __code_point_view(const char* __first, const char* __last)
      : __first_(__first), __last_(__last) {}

  _LIBCPP_HIDE_FROM_ABI constexpr bool __at_end() const noexcept { return __first_ == __last_; }
  _LIBCPP_HIDE_FROM_ABI constexpr const char* __position() const noexcept { return __first_; }

  _LIBCPP_HIDE_FROM_ABI constexpr char32_t __consume() noexcept {
    _LIBCPP_ASSERT(__first_ != __last_, "can't move beyond the end of input");

    // Based on the number of leading 1 bits the number of code units in the
    // code point can be determined. See
    // https://en.wikipedia.org/wiki/UTF-8#Encoding
    switch (_VSTD::countl_one(static_cast<unsigned char>(*__first_))) {
    case 0:
      return *__first_++;

    case 2:
      if (__last_ - __first_ < 2 || !__unicode::__is_continuation(__first_ + 1, 1)) [[unlikely]]
        break;
      else {
        char32_t __value = static_cast<unsigned char>(*__first_++) & 0x1f;
        __value <<= 6;
        __value |= static_cast<unsigned char>(*__first_++) & 0x3f;
        return __value;
      }

    case 3:
      if (__last_ - __first_ < 3 || !__unicode::__is_continuation(__first_ + 1, 2)) [[unlikely]]
        break;
      else {
        char32_t __value = static_cast<unsigned char>(*__first_++) & 0x0f;
        __value <<= 6;
        __value |= static_cast<unsigned char>(*__first_++) & 0x3f;
        __value <<= 6;
        __value |= static_cast<unsigned char>(*__first_++) & 0x3f;
        return __value;
      }

    case 4:
      if (__last_ - __first_ < 4 || !__unicode::__is_continuation(__first_ + 1, 3)) [[unlikely]]
        break;
      else {
        char32_t __value = static_cast<unsigned char>(*__first_++) & 0x07;
        __value <<= 6;
        __value |= static_cast<unsigned char>(*__first_++) & 0x3f;
        __value <<= 6;
        __value |= static_cast<unsigned char>(*__first_++) & 0x3f;
        __value <<= 6;
        __value |= static_cast<unsigned char>(*__first_++) & 0x3f;
        return __value;
      }
    }
    // An invalid number of leading ones can be garbage or a code unit in the
    // middle of a code point. By consuming one code unit the parser may get
    // "in sync" after a few code units.
    ++__first_;
    return __replacement_character;
  }

private:
  const char* __first_;
  const char* __last_;
};

#    ifndef TEST_HAS_NO_WIDE_CHARACTERS
/// This specialization depends on the size of wchar_t
/// - 2 UTF-16 (for example Windows and AIX)
/// - 4 UTF-32 (for example Linux)
template <>
class __code_point_view<wchar_t> {
public:
  _LIBCPP_HIDE_FROM_ABI constexpr explicit __code_point_view(const wchar_t* __first, const wchar_t* __last)
      : __first_(__first), __last_(__last) {}

  _LIBCPP_HIDE_FROM_ABI constexpr const wchar_t* __position() const noexcept { return __first_; }
  _LIBCPP_HIDE_FROM_ABI constexpr bool __at_end() const noexcept { return __first_ == __last_; }

  _LIBCPP_HIDE_FROM_ABI constexpr char32_t __consume() noexcept {
    _LIBCPP_ASSERT(__first_ != __last_, "can't move beyond the end of input");

    if constexpr (sizeof(wchar_t) == 2) {
      char32_t __result = *__first_++;
      // Is the code unit part of a surrogate pair? See
      // https://en.wikipedia.org/wiki/UTF-16#U+D800_to_U+DFFF
      if (__result >= 0xd800 && __result <= 0xDfff) {
        // Malformed Unicode.
        if (__first_ == __last_) [[unlikely]]
          return __replacement_character;

        __result -= 0xd800;
        __result <<= 10;
        __result += *__first_++ - 0xdc00;
        __result += 0x10000;
      }
      return __result;

    } else if constexpr (sizeof(wchar_t) == 4) {
      char32_t __result = *__first_++;
      if (__result > 0x10FFFF) [[unlikely]]
        return __replacement_character;
      return __result;
    } else {
      // TODO FMT P2593R0 Use static_assert(false, "sizeof(wchar_t) has a not implemented value");
      _LIBCPP_ASSERT(sizeof(wchar_t) == 0, "sizeof(wchar_t) has a not implemented value");
      __libcpp_unreachable();
    }
  }

private:
  const wchar_t* __first_;
  const wchar_t* __last_;
};
#    endif

_LIBCPP_HIDE_FROM_ABI constexpr bool __at_extended_grapheme_cluster_break(
    bool& __ri_break_allowed,
    bool __has_extened_pictographic,
    __extended_grapheme_custer_property_boundary::__property __prev,
    __extended_grapheme_custer_property_boundary::__property __next) {
  using __extended_grapheme_custer_property_boundary::__property;

  __has_extened_pictographic |= __prev == __property::__Extended_Pictographic;

  // https://www.unicode.org/reports/tr29/tr29-39.html#Grapheme_Cluster_Boundary_Rules

  // *** Break at the start and end of text, unless the text is empty. ***

  _LIBCPP_ASSERT(__prev != __property::__sot, "should be handled in the constructor"); // GB1
  _LIBCPP_ASSERT(__prev != __property::__eot, "should be handled by our caller");      // GB2

  // *** Do not break between a CR and LF. Otherwise, break before and after controls. ***
  if (__prev == __property::__CR && __next == __property::__LF) // GB3
    return false;

  if (__prev == __property::__Control || __prev == __property::__CR || __prev == __property::__LF) // GB4
    return true;

  if (__next == __property::__Control || __next == __property::__CR || __next == __property::__LF) // GB5
    return true;

  // *** Do not break Hangul syllable sequences. ***
  if (__prev == __property::__L &&
      (__next == __property::__L || __next == __property::__V || __next == __property::__LV ||
       __next == __property::__LVT)) // GB6
    return false;

  if ((__prev == __property::__LV || __prev == __property::__V) &&
      (__next == __property::__V || __next == __property::__T)) // GB7
    return false;

  if ((__prev == __property::__LVT || __prev == __property::__T) && __next == __property::__T) // GB8
    return false;

  // *** Do not break before extending characters or ZWJ. ***
  if (__next == __property::__Extend || __next == __property::__ZWJ)
    return false; // GB9

  // *** Do not break before SpacingMarks, or after Prepend characters. ***
  if (__next == __property::__SpacingMark) // GB9a
    return false;

  if (__prev == __property::__Prepend) // GB9b
    return false;

  // *** Do not break within emoji modifier sequences or emoji zwj sequences. ***

  // GB11 \p{Extended_Pictographic} Extend* ZWJ x \p{Extended_Pictographic}
  //
  // Note that several parts of this rule are matched by GB9: Any x (Extend | ZWJ)
  // - \p{Extended_Pictographic} x Extend
  // - Extend x Extend
  // - \p{Extended_Pictographic} x ZWJ
  // - Extend x ZWJ
  //
  // So the only case left to test is
  // - \p{Extended_Pictographic}' x ZWJ x \p{Extended_Pictographic}
  //   where  \p{Extended_Pictographic}' is stored in __has_extened_pictographic
  if (__has_extened_pictographic && __prev == __property::__ZWJ && __next == __property::__Extended_Pictographic)
    return false;

  // *** Do not break within emoji flag sequences ***

  // That is, do not break between regional indicator (RI) symbols if there
  // is an odd number of RI characters before the break point.

  if (__prev == __property::__Regional_Indicator && __next == __property::__Regional_Indicator) { // GB12 + GB13
    __ri_break_allowed = !__ri_break_allowed;
    if (__ri_break_allowed)
      return true;

    return false;
  }

  // *** Otherwise, break everywhere. ***
  return true; // GB999
}

/// Helper class to extract an extended grapheme cluster from a Unicode character range.
///
/// This function is used to determine the column width of an extended grapheme
/// cluster. In order to do that only the first code point is evaluated.
/// Therefore only this code point is extracted.
template <class _CharT>
class __extended_grapheme_cluster_view {
public:
  _LIBCPP_HIDE_FROM_ABI constexpr explicit __extended_grapheme_cluster_view(const _CharT* __first, const _CharT* __last)
      : __code_point_view_(__first, __last),
        __next_code_point_(__code_point_view_.__consume()),
        __next_prop_(__extended_grapheme_custer_property_boundary::__get_property(__next_code_point_)) {}

  struct __cluster {
    /// The first code point of the extended grapheme cluster.
    ///
    /// The first code point is used to estimate the width of the extended
    /// grapheme cluster.
    char32_t __code_point_;

    /// Points one beyond the last code unit in the extended grapheme cluster.
    ///
    /// It's expected the caller has the start position and thus can determine
    /// the code unit range of the extended grapheme cluster.
    const _CharT* __last_;
  };

  _LIBCPP_HIDE_FROM_ABI constexpr __cluster __consume() {
    _LIBCPP_ASSERT(
        __next_prop_ != __extended_grapheme_custer_property_boundary::__property::__eot,
        "can't move beyond the end of input");
    char32_t __code_point = __next_code_point_;
    if (!__code_point_view_.__at_end())
      return {__code_point, __get_break()};

    __next_prop_ = __extended_grapheme_custer_property_boundary::__property::__eot;
    return {__code_point, __code_point_view_.__position()};
  }

private:
  __code_point_view<_CharT> __code_point_view_;

  char32_t __next_code_point_;
  __extended_grapheme_custer_property_boundary::__property __next_prop_;

  _LIBCPP_HIDE_FROM_ABI constexpr const _CharT* __get_break() {
    bool __ri_break_allowed         = true;
    bool __has_extened_pictographic = false;
    while (true) {
      const _CharT* __result                                          = __code_point_view_.__position();
      __extended_grapheme_custer_property_boundary::__property __prev = __next_prop_;
      if (__code_point_view_.__at_end()) {
        __next_prop_ = __extended_grapheme_custer_property_boundary::__property::__eot;
        return __result;
      }
      __next_code_point_ = __code_point_view_.__consume();
      __next_prop_       = __extended_grapheme_custer_property_boundary::__get_property(__next_code_point_);

      __has_extened_pictographic |=
          __prev == __extended_grapheme_custer_property_boundary::__property::__Extended_Pictographic;

      if (__at_extended_grapheme_cluster_break(__ri_break_allowed, __has_extened_pictographic, __prev, __next_prop_))
        return __result;
    }
  }
};

} // namespace __unicode

#  endif //  _LIBCPP_HAS_NO_UNICODE

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___FORMAT_UNICODE_H
