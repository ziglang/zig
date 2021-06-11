#include <stdlib.h>
#include <errno.h>

void *__reallocarray(void *ptr, size_t nmemb, size_t size) {
    size_t bytes;
    if (__builtin_umull_overflow(nmemb, size, &bytes)) {
        errno = ENOMEM;
        return NULL;
    }
    return realloc(ptr, bytes);
}

void *reallocarray(void *ptr, size_t nmemb, size_t size)
    __attribute__((__weak__, __alias__("__reallocarray")));
