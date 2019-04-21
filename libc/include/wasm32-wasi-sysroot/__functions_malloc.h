#ifndef __wasm_basics___functions_malloc_h
#define __wasm_basics___functions_malloc_h

#define __need_size_t
#define __need_wchar_t
#define __need_NULL
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void *malloc(size_t size) __attribute__((__malloc__, __warn_unused_result__));
void free(void *ptr);
void *calloc(size_t nmemb, size_t size) __attribute__((__malloc__, __warn_unused_result__));
void *realloc(void *ptr, size_t size) __attribute__((__warn_unused_result__));

#ifdef __cplusplus
}
#endif

#endif
