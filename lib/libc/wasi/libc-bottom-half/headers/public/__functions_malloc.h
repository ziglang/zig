#ifndef __wasilibc___functions_malloc_h
#define __wasilibc___functions_malloc_h

#define __need_size_t
#define __need_wchar_t
#define __need_NULL
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void *malloc(size_t __size) __attribute__((__malloc__, __warn_unused_result__));
void free(void *__ptr);
void *calloc(size_t __nmemb, size_t __size) __attribute__((__malloc__, __warn_unused_result__));
void *realloc(void *__ptr, size_t __size) __attribute__((__warn_unused_result__));

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
void *reallocarray(void *__ptr, size_t __nmemb, size_t __size) __attribute__((__warn_unused_result__));
#endif

#ifdef __cplusplus
}
#endif

#endif
