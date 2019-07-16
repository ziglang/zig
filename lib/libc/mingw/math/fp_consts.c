/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include "fp_consts.h"
const union _ieee_rep __QNAN = { __DOUBLE_QNAN_REP };
const union _ieee_rep __SNAN = { __DOUBLE_SNAN_REP };
const union _ieee_rep __INF =  { __DOUBLE_INF_REP };
const union _ieee_rep __DENORM = { __DOUBLE_DENORM_REP };

/* ISO C99 */
#undef nan
/* FIXME */
double nan (const char *);
double nan (const char * tagp __attribute__((unused)) )
{
	return __QNAN.double_val;
}

