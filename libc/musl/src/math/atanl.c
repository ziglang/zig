/* origin: FreeBSD /usr/src/lib/msun/src/s_atanl.c */
/*
 * ====================================================
 * Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
 *
 * Developed at SunPro, a Sun Microsystems, Inc. business.
 * Permission to use, copy, modify, and distribute this
 * software is freely granted, provided that this notice
 * is preserved.
 * ====================================================
 */
/*
 * See comments in atan.c.
 * Converted to long double by David Schultz <das@FreeBSD.ORG>.
 */

#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double atanl(long double x)
{
	return atan(x);
}
#elif (LDBL_MANT_DIG == 64 || LDBL_MANT_DIG == 113) && LDBL_MAX_EXP == 16384

#if LDBL_MANT_DIG == 64
#define EXPMAN(u) ((u.i.se & 0x7fff)<<8 | (u.i.m>>55 & 0xff))

static const long double atanhi[] = {
	 4.63647609000806116202e-01L,
	 7.85398163397448309628e-01L,
	 9.82793723247329067960e-01L,
	 1.57079632679489661926e+00L,
};

static const long double atanlo[] = {
	 1.18469937025062860669e-20L,
	-1.25413940316708300586e-20L,
	 2.55232234165405176172e-20L,
	-2.50827880633416601173e-20L,
};

static const long double aT[] = {
	 3.33333333333333333017e-01L,
	-1.99999999999999632011e-01L,
	 1.42857142857046531280e-01L,
	-1.11111111100562372733e-01L,
	 9.09090902935647302252e-02L,
	-7.69230552476207730353e-02L,
	 6.66661718042406260546e-02L,
	-5.88158892835030888692e-02L,
	 5.25499891539726639379e-02L,
	-4.70119845393155721494e-02L,
	 4.03539201366454414072e-02L,
	-2.91303858419364158725e-02L,
	 1.24822046299269234080e-02L,
};

static long double T_even(long double x)
{
	return aT[0] + x * (aT[2] + x * (aT[4] + x * (aT[6] +
		x * (aT[8] + x * (aT[10] + x * aT[12])))));
}

static long double T_odd(long double x)
{
	return aT[1] + x * (aT[3] + x * (aT[5] + x * (aT[7] +
		x * (aT[9] + x * aT[11]))));
}
#elif LDBL_MANT_DIG == 113
#define EXPMAN(u) ((u.i.se & 0x7fff)<<8 | u.i.top>>8)

const long double atanhi[] = {
	 4.63647609000806116214256231461214397e-01L,
	 7.85398163397448309615660845819875699e-01L,
	 9.82793723247329067985710611014666038e-01L,
	 1.57079632679489661923132169163975140e+00L,
};

const long double atanlo[] = {
	 4.89509642257333492668618435220297706e-36L,
	 2.16795253253094525619926100651083806e-35L,
	-2.31288434538183565909319952098066272e-35L,
	 4.33590506506189051239852201302167613e-35L,
};

const long double aT[] = {
	 3.33333333333333333333333333333333125e-01L,
	-1.99999999999999999999999999999180430e-01L,
	 1.42857142857142857142857142125269827e-01L,
	-1.11111111111111111111110834490810169e-01L,
	 9.09090909090909090908522355708623681e-02L,
	-7.69230769230769230696553844935357021e-02L,
	 6.66666666666666660390096773046256096e-02L,
	-5.88235294117646671706582985209643694e-02L,
	 5.26315789473666478515847092020327506e-02L,
	-4.76190476189855517021024424991436144e-02L,
	 4.34782608678695085948531993458097026e-02L,
	-3.99999999632663469330634215991142368e-02L,
	 3.70370363987423702891250829918659723e-02L,
	-3.44827496515048090726669907612335954e-02L,
	 3.22579620681420149871973710852268528e-02L,
	-3.03020767654269261041647570626778067e-02L,
	 2.85641979882534783223403715930946138e-02L,
	-2.69824879726738568189929461383741323e-02L,
	 2.54194698498808542954187110873675769e-02L,
	-2.35083879708189059926183138130183215e-02L,
	 2.04832358998165364349957325067131428e-02L,
	-1.54489555488544397858507248612362957e-02L,
	 8.64492360989278761493037861575248038e-03L,
	-2.58521121597609872727919154569765469e-03L,
};

static long double T_even(long double x)
{
	return (aT[0] + x * (aT[2] + x * (aT[4] + x * (aT[6] + x * (aT[8] +
		x * (aT[10] + x * (aT[12] + x * (aT[14] + x * (aT[16] +
		x * (aT[18] + x * (aT[20] + x * aT[22])))))))))));
}

static long double T_odd(long double x)
{
	return (aT[1] + x * (aT[3] + x * (aT[5] + x * (aT[7] + x * (aT[9] +
		x * (aT[11] + x * (aT[13] + x * (aT[15] + x * (aT[17] +
		x * (aT[19] + x * (aT[21] + x * aT[23])))))))))));
}
#endif

long double atanl(long double x)
{
	union ldshape u = {x};
	long double w, s1, s2, z;
	int id;
	unsigned e = u.i.se & 0x7fff;
	unsigned sign = u.i.se >> 15;
	unsigned expman;

	if (e >= 0x3fff + LDBL_MANT_DIG + 1) { /* if |x| is large, atan(x)~=pi/2 */
		if (isnan(x))
			return x;
		return sign ? -atanhi[3] : atanhi[3];
	}
	/* Extract the exponent and the first few bits of the mantissa. */
	expman = EXPMAN(u);
	if (expman < ((0x3fff - 2) << 8) + 0xc0) {  /* |x| < 0.4375 */
		if (e < 0x3fff - (LDBL_MANT_DIG+1)/2) {   /* if |x| is small, atanl(x)~=x */
			/* raise underflow if subnormal */
			if (e == 0)
				FORCE_EVAL((float)x);
			return x;
		}
		id = -1;
	} else {
		x = fabsl(x);
		if (expman < (0x3fff << 8) + 0x30) {  /* |x| < 1.1875 */
			if (expman < ((0x3fff - 1) << 8) + 0x60) { /*  7/16 <= |x| < 11/16 */
				id = 0;
				x = (2.0*x-1.0)/(2.0+x);
			} else {                                 /* 11/16 <= |x| < 19/16 */
				id = 1;
				x = (x-1.0)/(x+1.0);
			}
		} else {
			if (expman < ((0x3fff + 1) << 8) + 0x38) { /* |x| < 2.4375 */
				id = 2;
				x = (x-1.5)/(1.0+1.5*x);
			} else {                                 /* 2.4375 <= |x| */
				id = 3;
				x = -1.0/x;
			}
		}
	}
	/* end of argument reduction */
	z = x*x;
	w = z*z;
	/* break sum aT[i]z**(i+1) into odd and even poly */
	s1 = z*T_even(w);
	s2 = w*T_odd(w);
	if (id < 0)
		return x - x*(s1+s2);
	z = atanhi[id] - ((x*(s1+s2) - atanlo[id]) - x);
	return sign ? -z : z;
}
#endif
