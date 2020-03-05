/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include "mb_wc_common.h"
#include <wchar.h>
#include <stdlib.h>
#include <errno.h>
#include <windows.h>

static int __MINGW_ATTRIB_NONNULL(1) __MINGW_ATTRIB_NONNULL(4)
__mbrtowc_cp (wchar_t * __restrict__ pwc, const char * __restrict__ s,
	      size_t n, mbstate_t* __restrict__ ps,
	      const unsigned int cp, const unsigned int mb_max) 
{
  union {
    mbstate_t val;
    char mbcs[4];
  } shift_state;

  /* Do the prelim checks */
  if (s == NULL)
    return 0;

  if (n == 0)
    /* The standard doesn't mention this case explicitly. Tell
       caller that the conversion from a non-null s is incomplete. */
    return -2;

  /* Save the current shift state, in case we need it in DBCS case.  */
  shift_state.val = *ps;
  *ps = 0;

  if (!*s)
    {
      *pwc = 0;
      return 0;
    }

  if (mb_max > 1)
    {
      if (shift_state.mbcs[0] != 0)
	{
	  /* Complete the mb char with the trailing byte.  */
	  shift_state.mbcs[1] = *s;  /* the second byte */
	  if (MultiByteToWideChar(cp, MB_ERR_INVALID_CHARS,
				  shift_state.mbcs, 2, pwc, 1)
		 == 0)
	    {
	      /* An invalid trailing byte */
	      errno = EILSEQ;
	      return -1;
	    }
	  return 2;
	}
      else if (IsDBCSLeadByteEx (cp, *s))
	{
	  /* If told to translate one byte, just save the leadbyte
	     in *ps.  */
	  if (n < 2)
	    {
	      ((char*) ps)[0] = *s;
	      return -2;
	    }
	  /* Else translate the first two bytes  */  
	  else if (MultiByteToWideChar (cp, MB_ERR_INVALID_CHARS,
					s, 2, pwc, 1)
		    == 0)
	    {
	      errno = EILSEQ;
	      return -1;
	    }
	  return 2;
	}
    }

  /* Fall through to single byte char  */
  if (cp == 0)
      *pwc = (wchar_t)(unsigned char)*s;

  else if (MultiByteToWideChar (cp, MB_ERR_INVALID_CHARS, s, 1, pwc, 1)
	    == 0)
    {
      errno = EILSEQ;
      return  -1;
    }

  return 1;
}

size_t
mbrtowc (wchar_t * __restrict__ pwc, const char * __restrict__ s,
	 size_t n, mbstate_t* __restrict__ ps)
{
  static mbstate_t internal_mbstate = 0;
  wchar_t  byte_bucket = 0;
  wchar_t* dst = pwc ? pwc : &byte_bucket;

  return (size_t) __mbrtowc_cp (dst, s, n, ps ? ps : &internal_mbstate,
				___lc_codepage_func(), MB_CUR_MAX);
}


size_t
mbsrtowcs (wchar_t* __restrict__ dst,  const char ** __restrict__ src,
	   size_t len, mbstate_t* __restrict__ ps)
{
  int ret =0 ;
  size_t n = 0;
  static mbstate_t internal_mbstate = 0;
  mbstate_t* internal_ps = ps ? ps : &internal_mbstate;
  const unsigned int cp = ___lc_codepage_func();
  const unsigned int mb_max = MB_CUR_MAX;

  if (src == NULL || *src == NULL)	/* undefined behavior */
    return 0;

  if (dst != NULL)
    {
      while (n < len
	     && (ret = __mbrtowc_cp(dst, *src, len - n,
				    internal_ps, cp, mb_max))
		  > 0)
	{
	  ++dst;
	  *src += ret;
	  n += ret;
	}

      if (n < len && ret == 0)
	*src = (char *)NULL;
    }
  else
    {
      wchar_t byte_bucket = 0;
      while ((ret = __mbrtowc_cp (&byte_bucket, *src + n, mb_max,
				     internal_ps, cp, mb_max))
		  > 0)
	n += ret;
    }
  return n;
}

size_t
mbrlen (const char * __restrict__ s, size_t n,
	mbstate_t * __restrict__ ps)
{
  static mbstate_t s_mbstate = 0;
  wchar_t byte_bucket = 0;
  return __mbrtowc_cp (&byte_bucket, s, n, (ps) ? ps : &s_mbstate,
		       ___lc_codepage_func(), MB_CUR_MAX);
}
