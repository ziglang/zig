#ifndef __wasilibc___header_stdlib_h
#define __wasilibc___header_stdlib_h

#define __need_size_t
#include <stddef.h>

#include <__functions_malloc.h>

#ifdef __cplusplus
extern "C" {
#endif

void abort(void) __attribute__((__noreturn__));
void qsort(void *, size_t, size_t, int (*)(const void *, const void *));
void _Exit(int) __attribute__((__noreturn__));

#ifdef __cplusplus
}
#endif

#endif
