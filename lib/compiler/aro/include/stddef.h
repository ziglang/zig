/* <stddef.h> for the Aro C compiler */

#pragma once

#define __STDC_VERSION_STDDEF_H__ 202311L

typedef __PTRDIFF_TYPE__ ptrdiff_t;
typedef __SIZE_TYPE__ size_t;
typedef __WCHAR_TYPE__ wchar_t;

/* define max_align_t to match GCC and Clang */
typedef struct {
  long long __aro_max_align_ll;
  long double __aro_max_align_ld;
} max_align_t;

#define NULL ((void*)0)
#define offsetof(T, member) __builtin_offsetof(T, member)

#if __STDC_VERSION__ >= 202311L
#  pragma GCC diagnostic push
#  pragma GCC diagnostic ignored "-Wpre-c23-compat"
   typedef typeof(nullptr) nullptr_t;
#  pragma GCC diagnostic pop

#  if defined unreachable
#    error unreachable() is a standard macro in C23
#  else
#    define unreachable() __builtin_unreachable()
#  endif
#endif
