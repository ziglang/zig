/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <math.h>

double log2(double x)
{
    return log(x) / 0.69314718246459960938;
}

float log2f(float x)
{
    return logf(x) / 0.69314718246459960938f;
}

long double log2l(long double x)
{
#if defined(__aarch64__) || defined(_ARM64_)
    return log2(x);
#else
#error Not supported on your platform yet
#endif
}
