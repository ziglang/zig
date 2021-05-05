#ifndef __wasilibc___header_string_h
#define __wasilibc___header_string_h

#define __need_size_t
#define __need_NULL
#include <stddef.h>

#include <__functions_memcpy.h>

#ifdef __cplusplus
extern "C" {
#endif

size_t strlen(const char *) __attribute__((__nothrow__, __leaf__, __pure__, __nonnull__(1)));
char *strdup(const char *) __attribute__((__nothrow__, __nonnull__(1)));
int strcmp(const char *, const char *) __attribute__((__nothrow__, __pure__, __nonnull__(1, 2)));
void *memchr(const void *, int, size_t) __attribute__((__nothrow__, __pure__, __nonnull__(1)));

#ifdef __cplusplus
}
#endif

#endif
