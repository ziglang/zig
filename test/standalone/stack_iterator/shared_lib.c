#include <stdint.h>

#ifndef LIB_API
#define LIB_API
#endif

__attribute__((noinline)) void frame1(
    void** expected,
    void** unwound,
    void (*frame2)(void** expected, void** unwound)) {
    expected[3] = __builtin_extract_return_addr(__builtin_return_address(0));
    frame2(expected, unwound);
}

LIB_API void frame0(
    void** expected,
    void** unwound,
    void (*frame2)(void** expected, void** unwound)) {
    expected[4] = __builtin_extract_return_addr(__builtin_return_address(0));
    frame1(expected, unwound, frame2);
}

