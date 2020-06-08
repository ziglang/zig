/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "fp_consts.h"
#include <math.h>

const union _ieee_rep __QNANL = { __LONG_DOUBLE_QNAN_REP };
const union _ieee_rep __SNANL = { __LONG_DOUBLE_SNAN_REP };
const union _ieee_rep __INFL  = { __LONG_DOUBLE_INF_REP };
const union _ieee_rep __DENORML = { __LONG_DOUBLE_DENORM_REP };

#undef nanl
/* FIXME */
long double nanl (const char *);
long double nanl (const char * tagp __attribute__((unused)) )
{
#if defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
  return nan("");
#else
  return __QNANL.ldouble_val;
#endif
}

