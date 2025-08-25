// Wasm's `min` and `max` operators implement the IEEE 754-2019
// `minimum` and `maximum` operations, meaning that given a choice
// between NaN and a number, they return NaN. This differs from
// the C standard library's `fmin` and `fmax` functions, which
// return the number. However, we can still use wasm's builtins
// by handling the NaN cases explicitly, and it still turns out
// to be faster than doing the whole operation in
// target-independent C. And, it's smaller.

#include <math.h>

float fminf(float x, float y) {
    if (isnan(x)) return y;
    if (isnan(y)) return x;
    return __builtin_wasm_min_f32(x, y);
}

float fmaxf(float x, float y) {
    if (isnan(x)) return y;
    if (isnan(y)) return x;
    return __builtin_wasm_max_f32(x, y);
}

double fmin(double x, double y) {
    if (isnan(x)) return y;
    if (isnan(y)) return x;
    return __builtin_wasm_min_f64(x, y);
}

double fmax(double x, double y) {
    if (isnan(x)) return y;
    if (isnan(y)) return x;
    return __builtin_wasm_max_f64(x, y);
}
