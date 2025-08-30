//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <cstdarg> // va_start, va_end
#include <cstddef> // size_t
#include <cstdio>  // vsprintf, vsnprintf
#include <cstdlib> // malloc
#include <cstring> // strcpy, wcsncpy
#include <cwchar>  // mbstate_t

// Returns >= 0: the number of wide characters found in the
// multi byte sequence src (of src_size_bytes), that fit in the buffer dst
// (of max_dest_chars elements size). The count returned excludes the
// null terminator. When dst is NULL, no characters are copied
// and no "out" parameters are updated.
// Returns (size_t) -1: an incomplete sequence encountered.
// Leaves *src pointing the next character to convert or NULL
// if a null character was converted from *src.
size_t mbsnrtowcs(wchar_t* __restrict dst,
                  const char** __restrict src,
                  size_t src_size_bytes,
                  size_t max_dest_chars,
                  mbstate_t* __restrict ps) {
  const size_t terminated_sequence = static_cast<size_t>(0);
  // const size_t invalid_sequence = static_cast<size_t>(-1);
  const size_t incomplete_sequence = static_cast< size_t>(-2);

  size_t dest_converted   = 0;
  size_t source_converted = 0;
  size_t source_remaining = src_size_bytes;
  size_t result           = 0;
  bool have_result        = false;

  // If dst is null then max_dest_chars should be ignored according to the
  // standard.  Setting max_dest_chars to a large value has this effect.
  if (!dst)
    max_dest_chars = static_cast<size_t>(-1);

  while (source_remaining) {
    if (dst && dest_converted >= max_dest_chars)
      break;
    // Converts one multi byte character.
    // if result > 0, it's the size in bytes of that character.
    // othewise if result is zero it indicates the null character has been found.
    // otherwise it's an error and errno may be set.
    size_t char_size = mbrtowc(dst ? dst + dest_converted : nullptr, *src + source_converted, source_remaining, ps);
    // Don't do anything to change errno from here on.
    if (char_size > 0) {
      source_remaining -= char_size;
      source_converted += char_size;
      ++dest_converted;
      continue;
    }
    result      = char_size;
    have_result = true;
    break;
  }
  if (dst) {
    if (have_result && result == terminated_sequence)
      *src = nullptr;
    else
      *src += source_converted;
  }
  if (have_result && result != terminated_sequence && result != incomplete_sequence)
    return static_cast<size_t>(-1);

  return dest_converted;
}

// Converts max_source_chars from the wide character buffer pointer to by *src,
// into the multi byte character sequence buffer stored at dst which must be
// dst_size_bytes bytes in size.
// Returns >= 0: the number of bytes in the sequence
// converted from *src, excluding the null terminator.
// Returns size_t(-1) if an error occurs, also sets errno.
// If dst is NULL dst_size_bytes is ignored and no bytes are copied to dst
// and no "out" parameters are updated.
size_t wcsnrtombs(char* __restrict dst,
                  const wchar_t** __restrict src,
                  size_t max_source_chars,
                  size_t dst_size_bytes,
                  mbstate_t* __restrict ps) {
  // const size_t invalid_sequence = static_cast<size_t>(-1);

  size_t source_converted = 0;
  size_t dest_converted   = 0;
  size_t dest_remaining   = dst_size_bytes;
  size_t char_size        = 0;
  const errno_t no_error  = (errno_t)0;
  errno_t result          = (errno_t)0;
  bool have_result        = false;
  bool terminator_found   = false;

  // If dst is null then dst_size_bytes should be ignored according to the
  // standard.  Setting dest_remaining to a large value has this effect.
  if (!dst)
    dest_remaining = static_cast<size_t>(-1);

  while (source_converted != max_source_chars) {
    if (!dest_remaining)
      break;
    wchar_t c = (*src)[source_converted];
    if (dst)
      result = wcrtomb_s(&char_size, dst + dest_converted, dest_remaining, c, ps);
    else
      result = wcrtomb_s(&char_size, nullptr, 0, c, ps);
    // If result is zero there is no error and char_size contains the
    // size of the multi-byte-sequence converted.
    // Otherwise result indicates an errno type error.
    if (result == no_error) {
      if (c == L'\0') {
        terminator_found = true;
        break;
      }
      ++source_converted;
      if (dst)
        dest_remaining -= char_size;
      dest_converted += char_size;
      continue;
    }
    have_result = true;
    break;
  }
  if (dst) {
    if (terminator_found)
      *src = nullptr;
    else
      *src = *src + source_converted;
  }
  if (have_result && result != no_error) {
    errno = result;
    return static_cast<size_t>(-1);
  }

  return dest_converted;
}
