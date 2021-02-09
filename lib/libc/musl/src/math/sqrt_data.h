#ifndef _SQRT_DATA_H
#define _SQRT_DATA_H

#include <features.h>
#include <stdint.h>

/* if x in [1,2): i = (int)(64*x);
   if x in [2,4): i = (int)(32*x-64);
   __rsqrt_tab[i]*2^-16 is estimating 1/sqrt(x) with small relative error:
   |__rsqrt_tab[i]*0x1p-16*sqrt(x) - 1| < -0x1.fdp-9 < 2^-8 */
extern hidden const uint16_t __rsqrt_tab[128];

#endif
