#ifndef __wasm_basics___functions_memcpy_h
#define __wasm_basics___functions_memcpy_h

#define __need_size_t
#define __need_NULL
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void *memcpy(void *__restrict__ dst, const void *__restrict__ src, size_t n) __attribute__((__nothrow__, __leaf__, __nonnull__(1, 2)));
void *memmove(void *dst, const void *src, size_t n) __attribute__((__nothrow__, __leaf__, __nonnull__(1, 2)));
void *memset(void *dst, int c, size_t n) __attribute__((__nothrow__, __leaf__, __nonnull__(1)));

#ifdef __cplusplus
}
#endif

#endif
