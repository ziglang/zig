#include <stdint.h>

#ifndef LIB_API
#define LIB_API
#endif

__attribute__((noinline)) void frame1(
    void** expected,
    void** unwound,
    void (*frame2)(void** expected, void** unwound)) {
    expected[2] = &&frame_2_ret;
    frame2(expected, unwound);
 frame_2_ret:
}

LIB_API void frame0(
    void** expected,
    void** unwound,
    void (*frame2)(void** expected, void** unwound)) {
    expected[3] = &&frame_1_ret;
    frame1(expected, unwound, frame2);
 frame_1_ret:
}

