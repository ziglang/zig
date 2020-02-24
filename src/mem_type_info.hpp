/*
 * Copyright (c) 2020 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_MEM_TYPE_INFO_HPP
#define ZIG_MEM_TYPE_INFO_HPP

#include "config.h"

#ifndef ZIG_TYPE_INFO_IMPLEMENTATION
#   ifdef ZIG_ENABLE_MEM_PROFILE
#       define ZIG_TYPE_INFO_IMPLEMENTATION 1
#   else
#       define ZIG_TYPE_INFO_IMPLEMENTATION 0
#   endif
#endif

namespace mem {

#if ZIG_TYPE_INFO_IMPLEMENTATION == 0

struct TypeInfo {
    size_t size;
    size_t alignment;

    template <typename T>
    static constexpr TypeInfo make() {
        return {sizeof(T), alignof(T)};
    }
};

#elif ZIG_TYPE_INFO_IMPLEMENTATION == 1

//
// A non-portable way to get a human-readable type-name compatible with
// non-RTTI C++ compiler mode; eg. `-fno-rtti`.
//
// Minimum requirements are c++11 and a compiler that has a constant for the
// current function's decorated name whereby a template-type name can be
// computed. eg. `__PRETTY_FUNCTION__` or `__FUNCSIG__`.
//
// given the following snippet:
//
//     |  #include <stdio.h>
//     |
//     |  struct Top {};
//     |  namespace mynamespace {
//     |      using custom = unsigned int;
//     |      struct Foo {
//     |          struct Bar {};
//     |      };
//     |  };
//     |
//     |  template <typename T>
//     |  void foobar() {
//     |  #ifdef _MSC_VER
//     |      fprintf(stderr, "--> %s\n", __FUNCSIG__);
//     |  #else
//     |      fprintf(stderr, "--> %s\n", __PRETTY_FUNCTION__);
//     |  #endif
//     |  }
//     |
//     |  int main() {
//     |      foobar<Top>();
//     |      foobar<unsigned int>();
//     |      foobar<mynamespace::custom>();
//     |      foobar<mynamespace::Foo*>();
//     |      foobar<mynamespace::Foo::Bar*>();
//     |  }
//
// gcc 9.2.0 produces:
//   --> void foobar() [with T = Top]
//   --> void foobar() [with T = unsigned int]
//   --> void foobar() [with T = unsigned int]
//   --> void foobar() [with T = mynamespace::Foo*]
//   --> void foobar() [with T = mynamespace::Foo::Bar*]
//
// xcode 11.3.1/clang produces:
//   --> void foobar() [T = Top]
//   --> void foobar() [T = unsigned int]
//   --> void foobar() [T = unsigned int]
//   --> void foobar() [T = mynamespace::Foo *]
//   --> void foobar() [T = mynamespace::Foo::Bar *]
//
// VStudio 2019 16.5.0/msvc produces:
//   --> void __cdecl foobar<struct Top>(void)
//   --> void __cdecl foobar<unsigned int>(void)
//   --> void __cdecl foobar<unsigned int>(void)
//   --> void __cdecl foobar<structmynamespace::Foo*>(void)
//   --> void __cdecl foobar<structmynamespace::Foo::Bar*>(void)
//
struct TypeInfo {
    const char *name_ptr;
    size_t name_len;
    size_t size;
    size_t alignment;

    static constexpr TypeInfo to_type_info(const char *str, size_t start, size_t end, size_t size, size_t alignment) {
        return TypeInfo{str + start, end - start, size, alignment};
    }

    static constexpr size_t index_of(const char *str, char c) {
        return *str == c ? 0 : 1 + index_of(str + 1, c);
    }

    template <typename T>
    static constexpr const char *decorated_name() {
#ifdef _MSC_VER
        return __FUNCSIG__;
#else
        return __PRETTY_FUNCTION__;
#endif
    }

    static constexpr TypeInfo extract(const char *decorated, size_t size, size_t alignment) {
#ifdef _MSC_VER
        return to_type_info(decorated, index_of(decorated, '<') + 1, index_of(decorated, '>'), size, alignment);
#else
        return to_type_info(decorated, index_of(decorated, '=') + 2, index_of(decorated, ']'), size, alignment);
#endif
    }

    template <typename T>
    static constexpr TypeInfo make() {
        return TypeInfo::extract(TypeInfo::decorated_name<T>(), sizeof(T), alignof(T));
    }
};

#endif // ZIG_TYPE_INFO_IMPLEMENTATION

} // namespace mem

#endif
