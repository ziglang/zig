/* <float.h> for the Aro C compiler */

#pragma once

#undef FLT_RADIX
#define FLT_RADIX __FLT_RADIX__

#undef FLT_MANT_DIG
#define FLT_MANT_DIG __FLT_MANT_DIG__

#undef DBL_MANT_DIG
#define DBL_MANT_DIG __DBL_MANT_DIG__

#undef LDBL_MANT_DIG
#define LDBL_MANT_DIG __LDBL_MANT_DIG__

#if __STDC_VERSION__ >= 199901L
#undef FLT_EVAL_METHOD
#define FLT_EVAL_METHOD __FLT_EVAL_METHOD__

#undef DECIMAL_DIG
#define DECIMAL_DIG __DECIMAL_DIG__
#endif  /* __STDC_VERSION__ >= 199901L */

#undef FLT_DIG
#define FLT_DIG __FLT_DIG__

#undef DBL_DIG
#define DBL_DIG __DBL_DIG__

#undef LDBL_DIG
#define LDBL_DIG __LDBL_DIG__

#undef FLT_MIN_EXP
#define FLT_MIN_EXP __FLT_MIN_EXP__

#undef DBL_MIN_EXP
#define DBL_MIN_EXP __DBL_MIN_EXP__

#undef LDBL_MIN_EXP
#define LDBL_MIN_EXP __LDBL_MIN_EXP__

#undef FLT_MIN_10_EXP
#define FLT_MIN_10_EXP __FLT_MIN_10_EXP__

#undef DBL_MIN_10_EXP
#define DBL_MIN_10_EXP __DBL_MIN_10_EXP__

#undef LDBL_MIN_10_EXP
#define LDBL_MIN_10_EXP __LDBL_MIN_10_EXP__

#undef FLT_MAX_EXP
#define FLT_MAX_EXP __FLT_MAX_EXP__

#undef DBL_MAX_EXP
#define DBL_MAX_EXP __DBL_MAX_EXP__

#undef LDBL_MAX_EXP
#define LDBL_MAX_EXP __LDBL_MAX_EXP__

#undef FLT_MAX_10_EXP
#define FLT_MAX_10_EXP __FLT_MAX_10_EXP__

#undef DBL_MAX_10_EXP
#define DBL_MAX_10_EXP __DBL_MAX_10_EXP__

#undef LDBL_MAX_10_EXP
#define LDBL_MAX_10_EXP __LDBL_MAX_10_EXP__

#undef FLT_MAX
#define FLT_MAX __FLT_MAX__

#undef DBL_MAX
#define DBL_MAX __DBL_MAX__

#undef LDBL_MAX
#define LDBL_MAX __LDBL_MAX__

#undef FLT_EPSILON
#define FLT_EPSILON __FLT_EPSILON__

#undef DBL_EPSILON
#define DBL_EPSILON __DBL_EPSILON__

#undef LDBL_EPSILON
#define LDBL_EPSILON __LDBL_EPSILON__

#undef FLT_MIN
#define FLT_MIN __FLT_MIN__

#undef DBL_MIN
#define DBL_MIN __DBL_MIN__

#undef LDBL_MIN
#define LDBL_MIN __LDBL_MIN__

#if __STDC_VERSION__ >= 201112L

#undef FLT_TRUE_MIN
#define FLT_TRUE_MIN __FLT_DENORM_MIN__

#undef DBL_TRUE_MIN
#define DBL_TRUE_MIN __DBL_DENORM_MIN__

#undef LDBL_TRUE_MIN
#define LDBL_TRUE_MIN __LDBL_DENORM_MIN__

#undef FLT_DECIMAL_DIG
#define FLT_DECIMAL_DIG __FLT_DECIMAL_DIG__

#undef DBL_DECIMAL_DIG
#define DBL_DECIMAL_DIG __DBL_DECIMAL_DIG__

#undef LDBL_DECIMAL_DIG
#define LDBL_DECIMAL_DIG __LDBL_DECIMAL_DIG__

#undef FLT_HAS_SUBNORM
#define FLT_HAS_SUBNORM __FLT_HAS_DENORM__

#undef DBL_HAS_SUBNORM
#define DBL_HAS_SUBNORM __DBL_HAS_DENORM__

#undef LDBL_HAS_SUBNORM
#define LDBL_HAS_SUBNORM __LDBL_HAS_DENORM__

#endif  /* __STDC_VERSION__ >= 201112L */
