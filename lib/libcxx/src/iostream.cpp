//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "std_stream.h"

#include <__memory/construct_at.h>
#include <__ostream/basic_ostream.h>
#include <istream>

#define ABI_NAMESPACE_STR _LIBCPP_TOSTRING(_LIBCPP_ABI_NAMESPACE)

_LIBCPP_BEGIN_NAMESPACE_STD

template <class StreamT, class BufferT>
union stream_data {
  constexpr stream_data() {}
  constexpr ~stream_data() {}
  struct {
    // The stream has to be the first element, since that's referenced by the stream declarations in <iostream>
    StreamT stream;
    BufferT buffer;
    mbstate_t mb;
  };

  void init(FILE* stdstream) {
    mb = {};
    std::construct_at(&buffer, stdstream, &mb);
    std::construct_at(&stream, &buffer);
  }
};

#define CHAR_MANGLING_char "D"
#define CHAR_MANGLING_wchar_t "_W"
#define CHAR_MANGLING(CharT) CHAR_MANGLING_##CharT

#ifdef _LIBCPP_COMPILER_CLANG_BASED
#  define STRING_DATA_CONSTINIT constinit
#else
#  define STRING_DATA_CONSTINIT
#endif

#ifdef _LIBCPP_ABI_MICROSOFT
#  define STREAM(StreamT, BufferT, CharT, var)                                                                         \
    STRING_DATA_CONSTINIT stream_data<StreamT<CharT>, BufferT<CharT>> var __asm__(                                     \
        "?" #var "@" ABI_NAMESPACE_STR "@std@@3V?$" #StreamT                                                           \
        "@" CHAR_MANGLING(CharT) "U?$char_traits@" CHAR_MANGLING(CharT) "@" ABI_NAMESPACE_STR "@std@@@12@A")
#else
#  define STREAM(StreamT, BufferT, CharT, var) STRING_DATA_CONSTINIT stream_data<StreamT<CharT>, BufferT<CharT>> var
#endif

// These definitions and the declarations in <iostream> technically cause ODR violations, since they have different
// types (stream_data and {i,o}stream respectively). This means that <iostream> should never be included in this TU.

_LIBCPP_EXPORTED_FROM_ABI STREAM(basic_istream, __stdinbuf, char, cin);
_LIBCPP_EXPORTED_FROM_ABI STREAM(basic_ostream, __stdoutbuf, char, cout);
_LIBCPP_EXPORTED_FROM_ABI STREAM(basic_ostream, __stdoutbuf, char, cerr);
_LIBCPP_EXPORTED_FROM_ABI STREAM(basic_ostream, __stdoutbuf, char, clog);
#if _LIBCPP_HAS_WIDE_CHARACTERS
_LIBCPP_EXPORTED_FROM_ABI STREAM(basic_istream, __stdinbuf, wchar_t, wcin);
_LIBCPP_EXPORTED_FROM_ABI STREAM(basic_ostream, __stdoutbuf, wchar_t, wcout);
_LIBCPP_EXPORTED_FROM_ABI STREAM(basic_ostream, __stdoutbuf, wchar_t, wcerr);
_LIBCPP_EXPORTED_FROM_ABI STREAM(basic_ostream, __stdoutbuf, wchar_t, wclog);
#endif // _LIBCPP_HAS_WIDE_CHARACTERS

// Pretend we're inside a system header so the compiler doesn't flag the use of the init_priority
// attribute with a value that's reserved for the implementation (we're the implementation).
#include "iostream_init.h"

// On Windows the TLS storage for locales needs to be initialized before we create
// the standard streams, otherwise it may not be alive during program termination
// when we flush the streams.
static void force_locale_initialization() {
#if defined(_LIBCPP_MSVCRT_LIKE)
  static bool once = []() {
    auto loc = __locale::__newlocale(_LIBCPP_ALL_MASK, "C", 0);
    {
      __locale::__locale_guard g(loc); // forces initialization of locale TLS
      ((void)g);
    }
    __locale::__freelocale(loc);
    return true;
  }();
  ((void)once);
#endif
}

class DoIOSInit {
public:
  DoIOSInit();
  ~DoIOSInit();
};

DoIOSInit::DoIOSInit() {
  force_locale_initialization();

  cin.init(stdin);
  cout.init(stdout);
  cerr.init(stderr);
  clog.init(stderr);

  cin.stream.tie(&cout.stream);
  std::unitbuf(cerr.stream);
  cerr.stream.tie(&cout.stream);

#if _LIBCPP_HAS_WIDE_CHARACTERS
  wcin.init(stdin);
  wcout.init(stdout);
  wcerr.init(stderr);
  wclog.init(stderr);

  wcin.stream.tie(&wcout.stream);
  std::unitbuf(wcerr.stream);
  wcerr.stream.tie(&wcout.stream);
#endif
}

DoIOSInit::~DoIOSInit() {
  cout.stream.flush();
  clog.stream.flush();

#if _LIBCPP_HAS_WIDE_CHARACTERS
  wcout.stream.flush();
  wclog.stream.flush();
#endif
}

ios_base::Init::Init() {
  static DoIOSInit init_the_streams; // gets initialized once
}

ios_base::Init::~Init() {}

_LIBCPP_END_NAMESPACE_STD
