#pragma once

// These are here because I hate most build systems (meson is OK)
#include "range2-neon.c"
#include "range2-sse.c"
#include "naive.c"

int utf8_naive(const unsigned char *data, int len);
int utf8_range2(const unsigned char *data, int len);

#ifdef __linux__
#ifdef __x86_64__
__attribute__ ((__target__ ("default")))
#endif
#endif
int utf8_range2(const unsigned char *data, int len)
{
    return utf8_naive(data, len);
}
