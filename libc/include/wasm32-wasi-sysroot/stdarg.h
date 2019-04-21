#ifdef __wasilibc_unmodified_upstream /* Use the compiler's stdarg.h */
#ifndef _STDARG_H
#define _STDARG_H

#ifdef __cplusplus
extern "C" {
#endif

#define __NEED_va_list

#include <bits/alltypes.h>

#define va_start(v,l)   __builtin_va_start(v,l)
#define va_end(v)       __builtin_va_end(v)
#define va_arg(v,l)     __builtin_va_arg(v,l)
#define va_copy(d,s)    __builtin_va_copy(d,s)

#ifdef __cplusplus
}
#endif

#endif
#else
/* Just use the compiler's stdarg.h. */
#include_next <stdarg.h>
#endif
