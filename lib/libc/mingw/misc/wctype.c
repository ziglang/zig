/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
/*
  wctype.c
  7.25.2.2.2 The wctype function

  Contributed by: Danny Smith  <dannysmith@usesr.sourcefoge.net>
		  2005-02-24
   
  This source code is placed in the PUBLIC DOMAIN. It is modified
  from the Q8 package created by Doug Gwyn <gwyn@arl.mil>  

  The wctype function constructs a value with type wctype_t that
  describes a class of wide characters identified by the string
  argument property.

  In particular, we map the property strings so that:

  iswctype(wc, wctype("alnum")) == iswalnum(wc) 
  iswctype(wc, wctype("alpha")) == iswalpha(wc)
  iswctype(wc, wctype("cntrl")) == iswcntrl(wc)
  iswctype(wc, wctype("digit")) == iswdigit(wc)
  iswctype(wc, wctype("graph")) == iswgraph(wc)
  iswctype(wc, wctype("lower")) == iswlower(wc)
  iswctype(wc, wctype("print")) == iswprint(wc)
  iswctype(wc, wctype("punct")) == iswpunct(wc)
  iswctype(wc, wctype("space")) == iswspace(wc)
  iswctype(wc, wctype("upper")) == iswupper(wc)
  iswctype(wc, wctype("xdigit")) == iswxdigit(wc)

*/

#include	<string.h>
#include	<wctype.h>

/* Using the bit-OR'd ctype character classification flags as return
   values achieves compatibility with MS iswctype().  */
static const struct {
  const char *name;
  wctype_t flags;} cmap[] = {
    {"alnum", _ALPHA|_DIGIT},
    {"alpha", _ALPHA},
    {"cntrl", _CONTROL},
    {"digit", _DIGIT},
    {"graph", _PUNCT|_ALPHA|_DIGIT},
    {"lower", _LOWER},
    {"print", _BLANK|_PUNCT|_ALPHA|_DIGIT},
    {"punct", _PUNCT},
    {"space", _SPACE},
    {"upper", _UPPER},
    {"xdigit", _HEX}
  };

#define NCMAP	(sizeof cmap / sizeof cmap[0])
wctype_t wctype (const char *property)
{
  int i;
  for (i = 0; i < (int) NCMAP; ++i)
    if (strcmp (property, cmap[i].name) == 0)
      return cmap[i].flags;
  return 0;
}
