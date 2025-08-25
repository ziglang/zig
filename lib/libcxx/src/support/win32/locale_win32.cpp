//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <__locale_dir/support/windows.h>
#include <clocale> // std::localeconv() & friends
#include <cstdarg> // va_start & friends
#include <cstddef>
#include <cstdio>  // std::vsnprintf & friends
#include <cstdlib> // std::strtof & friends
#include <ctime>   // std::strftime
#include <cwchar>  // wide char manipulation

_LIBCPP_BEGIN_NAMESPACE_STD
namespace __locale {

//
// Locale management
//
// FIXME: base and mask currently unused. Needs manual work to construct the new locale
__locale_t __newlocale(int /*mask*/, const char* locale, __locale_t /*base*/) {
  return {::_create_locale(LC_ALL, locale), locale};
}

__lconv_t* __localeconv(__locale_t& loc) {
  __locale_guard __current(loc);
  lconv* lc = std::localeconv();
  if (!lc)
    return lc;
  return loc.__store_lconv(lc);
}

//
// Strtonum functions
//
#if !defined(_LIBCPP_MSVCRT)
float __strtof(const char* nptr, char** endptr, __locale_t loc) {
  __locale_guard __current(loc);
  return std::strtof(nptr, endptr);
}

long double __strtold(const char* nptr, char** endptr, __locale_t loc) {
  __locale_guard __current(loc);
  return std::strtold(nptr, endptr);
}
#endif

//
// Character manipulation functions
//
#if defined(__MINGW32__) && __MSVCRT_VERSION__ < 0x0800
size_t __strftime(char* ret, size_t n, const char* format, const struct tm* tm, __locale_t loc) {
  __locale_guard __current(loc);
  return std::strftime(ret, n, format, tm);
}
#endif

//
// Other functions
//
decltype(MB_CUR_MAX) __mb_len_max(__locale_t __l) {
#if defined(_LIBCPP_MSVCRT)
  return ::___mb_cur_max_l_func(__l);
#else
  __locale_guard __current(__l);
  return MB_CUR_MAX;
#endif
}

wint_t __btowc(int c, __locale_t loc) {
  __locale_guard __current(loc);
  return std::btowc(c);
}

int __wctob(wint_t c, __locale_t loc) {
  __locale_guard __current(loc);
  return std::wctob(c);
}

size_t __wcsnrtombs(char* __restrict dst,
                    const wchar_t** __restrict src,
                    size_t nwc,
                    size_t len,
                    mbstate_t* __restrict ps,
                    __locale_t loc) {
  __locale_guard __current(loc);
  return ::wcsnrtombs(dst, src, nwc, len, ps);
}

size_t __wcrtomb(char* __restrict s, wchar_t wc, mbstate_t* __restrict ps, __locale_t loc) {
  __locale_guard __current(loc);
  return std::wcrtomb(s, wc, ps);
}

size_t __mbsnrtowcs(wchar_t* __restrict dst,
                    const char** __restrict src,
                    size_t nms,
                    size_t len,
                    mbstate_t* __restrict ps,
                    __locale_t loc) {
  __locale_guard __current(loc);
  return ::mbsnrtowcs(dst, src, nms, len, ps);
}

size_t
__mbrtowc(wchar_t* __restrict pwc, const char* __restrict s, size_t n, mbstate_t* __restrict ps, __locale_t loc) {
  __locale_guard __current(loc);
  return std::mbrtowc(pwc, s, n, ps);
}

size_t __mbrlen(const char* __restrict s, size_t n, mbstate_t* __restrict ps, __locale_t loc) {
  __locale_guard __current(loc);
  return std::mbrlen(s, n, ps);
}

size_t __mbsrtowcs(
    wchar_t* __restrict dst, const char** __restrict src, size_t len, mbstate_t* __restrict ps, __locale_t loc) {
  __locale_guard __current(loc);
  return std::mbsrtowcs(dst, src, len, ps);
}

int __snprintf(char* ret, size_t n, __locale_t loc, const char* format, ...) {
  va_list ap;
  va_start(ap, format);
#if defined(_LIBCPP_MSVCRT)
  // FIXME: Remove usage of internal CRT function and globals.
  int result = ::__stdio_common_vsprintf(
      _CRT_INTERNAL_LOCAL_PRINTF_OPTIONS | _CRT_INTERNAL_PRINTF_STANDARD_SNPRINTF_BEHAVIOR, ret, n, format, loc, ap);
#else
  __locale_guard __current(loc);
  _LIBCPP_DIAGNOSTIC_PUSH
  _LIBCPP_CLANG_DIAGNOSTIC_IGNORED("-Wformat-nonliteral")
  int result = std::vsnprintf(ret, n, format, ap);
  _LIBCPP_DIAGNOSTIC_POP
#endif
  va_end(ap);
  return result;
}

// Like sprintf, but when return value >= 0 it returns
// a pointer to a malloc'd string in *sptr.
// If return >= 0, use free to delete *sptr.
int __libcpp_vasprintf(char** sptr, const char* __restrict format, va_list ap) {
  *sptr = nullptr;
  // Query the count required.
  va_list ap_copy;
  va_copy(ap_copy, ap);
  _LIBCPP_DIAGNOSTIC_PUSH
  _LIBCPP_CLANG_DIAGNOSTIC_IGNORED("-Wformat-nonliteral")
  int count = vsnprintf(nullptr, 0, format, ap_copy);
  _LIBCPP_DIAGNOSTIC_POP
  va_end(ap_copy);
  if (count < 0)
    return count;
  size_t buffer_size = static_cast<size_t>(count) + 1;
  char* p            = static_cast<char*>(malloc(buffer_size));
  if (!p)
    return -1;
  // If we haven't used exactly what was required, something is wrong.
  // Maybe bug in vsnprintf. Report the error and return.
  _LIBCPP_DIAGNOSTIC_PUSH
  _LIBCPP_CLANG_DIAGNOSTIC_IGNORED("-Wformat-nonliteral")
  if (vsnprintf(p, buffer_size, format, ap) != count) {
    _LIBCPP_DIAGNOSTIC_POP
    free(p);
    return -1;
  }
  // All good. This is returning memory to the caller not freeing it.
  *sptr = p;
  return count;
}

int __asprintf(char** ret, __locale_t loc, const char* format, ...) {
  va_list ap;
  va_start(ap, format);
  __locale_guard __current(loc);
  return __libcpp_vasprintf(ret, format, ap);
}

} // namespace __locale
_LIBCPP_END_NAMESPACE_STD
