#ifndef __wasilibc___functions_memcpy_h
#define __wasilibc___functions_memcpy_h

#define __need_size_t
#define __need_NULL
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void *memcpy(void *__restrict__ __dst, const void *__restrict__ __src, size_t __n) __attribute__((__nothrow__, __leaf__, __nonnull__(1, 2)));
void *memmove(void *__dst, const void *__src, size_t __n) __attribute__((__nothrow__, __leaf__, __nonnull__(1, 2)));
void *memset(void *__dst, int __c, size_t __n) __attribute__((__nothrow__, __leaf__, __nonnull__(1)));

#ifdef __cplusplus
}
#endif

#endif
