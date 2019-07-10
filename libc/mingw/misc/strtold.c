/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include "math/cephes_emath.h"

#if NE == 10
/* 1.0E0 */
static const unsigned short __eone[NE] = {
  0x0000, 0x0000, 0x0000, 0x0000,
  0x0000, 0x0000, 0x0000, 0x0000, 0x8000, 0x3fff,
};
#else
static const unsigned short __eone[NE] = {
  0, 0000000,0000000,0000000,0100000,0x3fff,
};
#endif

#if NE == 10
static const unsigned short __etens[NTEN + 1][NE] =
{
  {0x6576, 0x4a92, 0x804a, 0x153f,
   0xc94c, 0x979a, 0x8a20, 0x5202, 0xc460, 0x7525,},	/* 10**4096 */
  {0x6a32, 0xce52, 0x329a, 0x28ce,
   0xa74d, 0x5de4, 0xc53d, 0x3b5d, 0x9e8b, 0x5a92,},	/* 10**2048 */
  {0x526c, 0x50ce, 0xf18b, 0x3d28,
   0x650d, 0x0c17, 0x8175, 0x7586, 0xc976, 0x4d48,},
  {0x9c66, 0x58f8, 0xbc50, 0x5c54,
   0xcc65, 0x91c6, 0xa60e, 0xa0ae, 0xe319, 0x46a3,},
  {0x851e, 0xeab7, 0x98fe, 0x901b,
   0xddbb, 0xde8d, 0x9df9, 0xebfb, 0xaa7e, 0x4351,},
  {0x0235, 0x0137, 0x36b1, 0x336c,
   0xc66f, 0x8cdf, 0x80e9, 0x47c9, 0x93ba, 0x41a8,},
  {0x50f8, 0x25fb, 0xc76b, 0x6b71,
   0x3cbf, 0xa6d5, 0xffcf, 0x1f49, 0xc278, 0x40d3,},
  {0x0000, 0x0000, 0x0000, 0x0000,
   0xf020, 0xb59d, 0x2b70, 0xada8, 0x9dc5, 0x4069,},
  {0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0400, 0xc9bf, 0x8e1b, 0x4034,},
  {0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x2000, 0xbebc, 0x4019,},
  {0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0x9c40, 0x400c,},
  {0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0xc800, 0x4005,},
  {0x0000, 0x0000, 0x0000, 0x0000,
   0x0000, 0x0000, 0x0000, 0x0000, 0xa000, 0x4002,},	/* 10**1 */
};
#else
static const unsigned short __etens[NTEN+1][NE] = {
  {0xc94c,0x979a,0x8a20,0x5202,0xc460,0x7525,},/* 10**4096 */
  {0xa74d,0x5de4,0xc53d,0x3b5d,0x9e8b,0x5a92,},/* 10**2048 */
  {0x650d,0x0c17,0x8175,0x7586,0xc976,0x4d48,},
  {0xcc65,0x91c6,0xa60e,0xa0ae,0xe319,0x46a3,},
  {0xddbc,0xde8d,0x9df9,0xebfb,0xaa7e,0x4351,},
  {0xc66f,0x8cdf,0x80e9,0x47c9,0x93ba,0x41a8,},
  {0x3cbf,0xa6d5,0xffcf,0x1f49,0xc278,0x40d3,},
  {0xf020,0xb59d,0x2b70,0xada8,0x9dc5,0x4069,},
  {0x0000,0x0000,0x0400,0xc9bf,0x8e1b,0x4034,},
  {0x0000,0x0000,0x0000,0x2000,0xbebc,0x4019,},
  {0x0000,0x0000,0x0000,0x0000,0x9c40,0x400c,},
  {0x0000,0x0000,0x0000,0x0000,0xc800,0x4005,},
  {0x0000,0x0000,0x0000,0x0000,0xa000,0x4002,}, /* 10**1 */
};
#endif

int __asctoe64(const char * __restrict__ ss, short unsigned int * __restrict__ y)
{
  unsigned short yy[NI], xt[NI], tt[NI];
  int esign, decflg, nexp, expo, lost;
  int k, c;
  int valid_lead_string = 0;
  int have_non_zero_mant = 0;
  int prec = 0;
  /* int trail = 0; */
  int lexp;
  unsigned short nsign = 0;
  const unsigned short *p;
  char *sp,  *lstr;
  char *s;

  const char dec_sym = *(localeconv ()->decimal_point); 

  int lenldstr = 0;

  /* Copy the input string. */
  c = strlen (ss) + 2;
  lstr = (char *) alloca (c);
  s = (char *) ss;
  while( isspace ((int)(unsigned char)*s)) /* skip leading spaces */
    {
      ++s;
      ++lenldstr;
    }
  sp = lstr;
  for (k = 0; k < c; k++)
    {
      if ((*sp++ = *s++) == '\0')
	break;
    }
  *sp = '\0';
  s = lstr;

  if (*s == '-')
    {
      nsign = 0xffff;
      ++s;
    }
  else if (*s == '+')
    {
     ++s;
    }

  if (_strnicmp("INF", s , 3) == 0)
    {
      valid_lead_string = 1;
      s += 3;
      if ( _strnicmp ("INITY", s, 5) == 0)
	s += 5;
      __ecleaz(yy);
      yy[E] = 0x7fff;  /* infinity */
      goto aexit;
    }
  else if(_strnicmp ("NAN", s, 3) == 0)
    {
      valid_lead_string = 1;
      s += 3;
      __enan_NI16( yy );
      goto aexit;
    }

  /* FIXME: Handle case of strtold ("NAN(n_char_seq)",endptr)  */ 

  /*  Now get some digits.  */
  lost = 0;
  decflg = 0;
  nexp = 0;
  expo = 0;
  __ecleaz( yy );

  /* Ignore leading zeros */
  while (*s == '0')
    {
      valid_lead_string = 1;
      s++;
    }

nxtcom:

  k = *s - '0';
  if ((k >= 0) && (k <= 9))
    {
#if 0
/* The use of a special char as a flag for trailing zeroes causes problems when input
   actually contains the char  */
/* Identify and strip trailing zeros after the decimal point. */
      if ((trail == 0) && (decflg != 0))
	{
	  sp = s;
	  while ((*sp >= '0') && (*sp <= '9'))
	    ++sp;
	  --sp;
	  while (*sp == '0')
	    {
	      *sp-- = (char)-1;
	      trail++;
	    }
	  if( *s == (char)-1 )
	    goto donchr;
	}
#endif

/* If enough digits were given to more than fill up the yy register,
 * continuing until overflow into the high guard word yy[2]
 * guarantees that there will be a roundoff bit at the top
 * of the low guard word after normalization.
 */
      if (yy[2] == 0)
	{
	  if( decflg )
	    nexp += 1; /* count digits after decimal point */
	  __eshup1( yy );	/* multiply current number by 10 */
	  __emovz( yy, xt );
	  __eshup1( xt );
	  __eshup1( xt );
	  __eaddm( xt, yy );
	  __ecleaz( xt );
	  xt[NI-2] = (unsigned short )k;
	  __eaddm( xt, yy );
	}
      else
	{
	  /* Mark any lost non-zero digit.  */
	  lost |= k;
	  /* Count lost digits before the decimal point.  */
	  if (decflg == 0)
	    nexp -= 1;
	}
      have_non_zero_mant |= k;
      prec ++;
      /* goto donchr; */
    }
  else if (*s == dec_sym)
    {
      if( decflg )
        goto daldone;
      ++decflg;
    }
  else if ((*s == 'E') || (*s == 'e') )
    {
      if (prec || valid_lead_string)
	goto expnt;
      else
	goto daldone;
    }
#if 0
  else if (*s == (char)-1)
    goto donchr;
#endif
  else  /* an invalid char */
    goto daldone;

  /* donchr: */
  ++s;
  goto nxtcom;

/* Exponent interpretation */
expnt:

  esign = 1;
  expo = 0;
  /* Save position in case we need to fall back.  */
  sp = s;
  ++s;
  /* check for + or - */
  if (*s == '-')
    {
      esign = -1;
      ++s;
    }
  if (*s == '+')
    ++s;

  /* Check for valid exponent.  */
  if (!(*s >= '0' && *s <= '9'))
    {
      s = sp;
      goto daldone;
    }

  while ((*s >= '0') && (*s <= '9'))
    {
    /* Stop modifying exp if we are going to overflow anyway,
       but keep parsing the string. */	
      if (expo < 4978)
	{
	  expo *= 10;
	  expo += *s - '0';
	}
      s++;
    }

  if (esign < 0)
    expo = -expo;

  if (expo > 4977) /* maybe overflow */
    {
      __ecleaz(yy);
      if (have_non_zero_mant)
	yy[E] = 0x7fff;
      goto aexit;
    }
  else if (expo < -4977) /* underflow */
    {
      __ecleaz(yy);
      goto aexit;
    }

daldone:

  nexp = expo - nexp;

  /* Pad trailing zeros to minimize power of 10, per IEEE spec. */
  while ((nexp > 0) && (yy[2] == 0))
    {
      __emovz( yy, xt );
      __eshup1( xt );
      __eshup1( xt );
      __eaddm( yy, xt );
      __eshup1( xt );
      if (xt[2] != 0)
	break;
      nexp -= 1;
      __emovz( xt, yy );
    }
  if ((k = __enormlz(yy)) > NBITS)
    {
      __ecleaz(yy);
      goto aexit;
    }
  lexp = (EXONE - 1 + NBITS) - k;
  __emdnorm( yy, lost, 0, lexp, 64, NBITS );
  /* convert to external format */

  /* Multiply by 10**nexp.  If precision is 64 bits,
   * the maximum relative error incurred in forming 10**n
   * for 0 <= n <= 324 is 8.2e-20, at 10**180.
   * For 0 <= n <= 999, the peak relative error is 1.4e-19 at 10**947.
   * For 0 >= n >= -999, it is -1.55e-19 at 10**-435.
   */
  lexp = yy[E];
  if (nexp == 0)
    {
      k = 0;
      goto expdon;
    }
  esign = 1;
  if (nexp < 0)
    {
      nexp = -nexp;
      esign = -1;
      if (nexp > 4096)
	{ /* Punt.  Can't handle this without 2 divides. */
	  __emovi( __etens[0], tt );
	  lexp -= tt[E];
	  k = __edivm( tt, yy );
	  lexp += EXONE;
	  nexp -= 4096;
	}
    }
  p = &__etens[NTEN][0];
  __emov( __eone, xt );
  expo = 1;
  do
    {
      if (expo & nexp)
	__emul( p, xt, xt );
      p -= NE;
      expo = expo + expo;
    }
  while (expo <= MAXP);

  __emovi( xt, tt );
  if (esign < 0)
    {
      lexp -= tt[E];
      k = __edivm( tt, yy );
      lexp += EXONE;
    }
  else
    {
      lexp += tt[E];
      k = __emulm( tt, yy );
      lexp -= EXONE - 1;
    }

expdon:

  /* Round and convert directly to the destination type */

  __emdnorm( yy, k, 0, lexp, 64, 64 );

aexit:

  yy[0] = nsign;

  __toe64( yy, y );

  /* Check for overflow, undeflow  */
  if (have_non_zero_mant &&
      (*((long double*) y) == 0.0L || isinf (*((long double*) y)))) 
    errno = ERANGE;

  if (prec || valid_lead_string)
    return (lenldstr + (s - lstr));

  return 0;
}


long double strtold (const char * __restrict__ s, char ** __restrict__ se)
{
  int lenldstr;
  union
  {
    unsigned short int us[6];
    long double ld;
  } xx = {{0}};

  lenldstr =  __asctoe64( s, xx.us);
  if (se)
    *se = (char*)s + lenldstr;

  return xx.ld;
}

