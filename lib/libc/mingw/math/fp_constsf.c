/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "fp_consts.h"

const union _ieee_rep __QNANF = { __FLOAT_QNAN_REP };
const union _ieee_rep __SNANF = { __FLOAT_SNAN_REP };
const union _ieee_rep __INFF  = { __FLOAT_INF_REP };
const union _ieee_rep __DENORMF = { __FLOAT_DENORM_REP };

/* ISO C99 */
#undef nanf
/* FIXME */
float nanf(const char *);

float nanf(const char * tagp __attribute__((unused)) )
{
  return __QNANF.float_val;
}

