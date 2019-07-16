/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
   wctrans.c 
   7.25.3.2 Extensible wide-character case mapping functions

   Contributed by: Danny Smith  <dannysmith@usesr.sourcefoge.net>
   		   2005-02-24
   
  This source code is placed in the PUBLIC DOMAIN. It is modified
  from the Q8 package created by Doug Gwyn <gwyn@arl.mil>  

 */

#include <string.h>
#include <wctype.h>

/*
   This differs from the MS implementation of wctrans which
   returns 0 for tolower and 1 for toupper.  According to
   C99, a 0 return value indicates invalid input.

   These two function go in the same translation unit so that we
   can ensure that
     towctrans(wc, wctrans("tolower")) == towlower(wc) 
     towctrans(wc, wctrans("toupper")) == towupper(wc)
   It also ensures that
     towctrans(wc, wctrans("")) == wc
   which is not required by standard.
*/

static const struct {
  const char *name;
  wctrans_t val; } tmap[] = {
    {"tolower", _LOWER},
    {"toupper", _UPPER}
 };

#define	NTMAP	(sizeof tmap / sizeof tmap[0])

wctrans_t
wctrans (const char* property)
{
  int i;
  for ( i = 0; i < (int) NTMAP; ++i )
    if (strcmp (property, tmap[i].name) == 0)
      return tmap[i].val;
   return 0;
}

wint_t towctrans (wint_t wc, wctrans_t desc)
{
  switch (desc)
    {
    case _LOWER:
      return towlower (wc);
    case _UPPER:
      return towupper (wc);
    default:
      return wc;
   }
}
