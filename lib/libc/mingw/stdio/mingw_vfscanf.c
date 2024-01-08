/*
 This Software is provided under the Zope Public License (ZPL) Version 2.1.

 Copyright (c) 2011 by the mingw-w64 project

 See the AUTHORS file for the list of contributors to the mingw-w64 project.

 This license has been certified as open source. It has also been designated
 as GPL compatible by the Free Software Foundation (FSF).

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

   1. Redistributions in source code must retain the accompanying copyright
      notice, this list of conditions, and the following disclaimer.
   2. Redistributions in binary form must reproduce the accompanying
      copyright notice, this list of conditions, and the following disclaimer
      in the documentation and/or other materials provided with the
      distribution.
   3. Names of the copyright holders must not be used to endorse or promote
      products derived from this software without prior written permission
      from the copyright holders.
   4. The right to distribute this software or to use it for any purpose does
      not give you the right to use Servicemarks (sm) or Trademarks (tm) of
      the copyright holders.  Use of them is covered by separate agreement
      with the copyright holders.
   5. If any files are modified, you must cause the modified files to carry
      prominent notices stating that you changed the files and the date of
      any change.

 Disclaimer

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY EXPRESSED
 OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#define __LARGE_MBSTATE_T

#include <limits.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <ctype.h>
#include <wctype.h>
#include <locale.h>
#include <errno.h>

/* Helper flags for conversion.  */
#define IS_C		0x0001
#define IS_S		0x0002
#define IS_L		0x0004
#define IS_LL		0x0008
#define IS_SIGNED_NUM	0x0010
#define IS_POINTER	0x0020
#define IS_HEX_FLOAT	0x0040
#define IS_SUPPRESSED	0x0080
#define USE_GROUP	0x0100
#define USE_GNU_ALLOC	0x0200
#define USE_POSIX_ALLOC	0x0400

#define IS_ALLOC_USED	(USE_GNU_ALLOC | USE_POSIX_ALLOC)

/* internal stream structure with back-buffer.  */
typedef struct _IFP
{
  __extension__ union {
    void *fp;
    const char *str;
  };
  int bch[1024];
  unsigned int is_string : 1;
  int back_top;
  unsigned int seen_eof : 1;
} _IFP;

static void *
get_va_nth (va_list argp, unsigned int n)
{
  va_list ap;
  if (!n) abort ();
  va_copy (ap, argp);
  while (--n > 0)
    (void) va_arg(ap, void *);
  return va_arg (ap, void *);
}

static void
optimize_alloc (char **p, char *end, size_t alloc_sz)
{
  size_t need_sz;
  char *h;

  if (!p || !*p)
    return;

  need_sz = end - *p;
  if (need_sz == alloc_sz)
    return;

  if ((h = (char *) realloc (*p, need_sz)) != NULL)
    *p = h;
}

static void
back_ch (int c, _IFP *s, size_t *rin, int not_eof)
{
  if (!not_eof && c == EOF)
    return;
  if (s->is_string == 0)
    {
      FILE *fp = s->fp;
      ungetc (c, fp);
      rin[0] -= 1;
      return;
    }
  rin[0] -= 1;
  s->bch[s->back_top] = c;
  s->back_top += 1;
}

static int
in_ch (_IFP *s, size_t *rin)
{
  int r;
  if (s->back_top)
  {
    s->back_top -= 1;
    r = s->bch[s->back_top];
    rin[0] += 1;
  }
  else if (s->seen_eof)
  {
    return EOF;
  }
  else if (s->is_string)
  {
    const char *ps = s->str;
    r = ((int) *ps) & 0xff;
    ps++;
    if (r != 0)
    {
      rin[0] += 1;
      s->str = ps;
      return r;
    }
    s->seen_eof = 1;
    return EOF;
  }
  else
  {
    FILE *fp = (FILE *) s->fp;
    r = getc (fp);
    if (r != EOF)
      rin[0] += 1;
    else s->seen_eof = 1;
  }
  return r;
}

static int
match_string (_IFP *s, size_t *rin, int *c, const char *str)
{
  int ch = *c;

  if (*str == 0)
    return 1;

  if (*str != (char) tolower (ch))
    return 0;
  ++str;
  while (*str != 0)
  {
    if ((ch = in_ch (s, rin)) == EOF)
    {
      c[0] = ch;
      return 0;
    }

    if (*str != (char) tolower (ch))
    {
      c[0] = ch;
      return 0;
    }
    ++str;
  }
  c[0] = ch;
  return 1;
}

struct gcollect
{
  size_t count;
  struct gcollect *next;
  char **ptrs[32];
};

static void
release_ptrs (struct gcollect **pt, char **wbuf)
{
  struct gcollect *pf;
  size_t cnt;

  if (wbuf)
    {
      free (*wbuf);
      *wbuf = NULL;
    }
  if (!pt || (pf = *pt) == NULL)
    return;
  while (pf != NULL)
    {
      struct gcollect *pf_sv = pf;
      for (cnt = 0; cnt < pf->count; ++cnt)
	{
	  free (*pf->ptrs[cnt]);
	  *pf->ptrs[cnt] = NULL;
	}
      pf = pf->next;
      free (pf_sv);
    }
  *pt = NULL;
}

static int
cleanup_return (int rval, struct gcollect **pfree, char **strp, char **wbuf)
{
  if (rval == EOF)
      release_ptrs (pfree, wbuf);
  else
    {
      if (pfree)
        {
          struct gcollect *pf = *pfree, *pf_sv;
          while (pf != NULL)
            {
              pf_sv = pf;
              pf = pf->next;
              free (pf_sv);
            }
          *pfree = NULL;
        }
      if (strp != NULL)
	{
	  free (*strp);
	  *strp = NULL;
	}
      if (wbuf)
	{
	  free (*wbuf);
	  *wbuf = NULL;
	}
    }
  return rval;
}

static struct gcollect *
resize_gcollect (struct gcollect *pf)
{
  struct gcollect *np;
  if (pf && pf->count < 32)
    return pf;
  np = malloc (sizeof (struct gcollect));
  np->count = 0;
  np->next = pf;
  return np;
}

static char *
resize_wbuf (size_t wpsz, size_t *wbuf_max_sz, char *old)
{
  char *wbuf;
  size_t nsz;
  if (*wbuf_max_sz != wpsz)
    return old;
  nsz = (256 > (2 * wbuf_max_sz[0]) ? 256 : (2 * wbuf_max_sz[0]));
  if (!old)
    wbuf = (char *) malloc (nsz);
  else
    wbuf = (char *) realloc (old, nsz);
  if (!wbuf)
  {
    if (old)
      free (old);
  }
  else
    *wbuf_max_sz = nsz;
  return wbuf;
}

static int
__mingw_sformat (_IFP *s, const char *format, va_list argp)
{
  const char *f = format;
  struct gcollect *gcollect = NULL;
  size_t read_in = 0, wbuf_max_sz = 0, cnt;
  ssize_t str_sz = 0;
  char *str = NULL, **pstr = NULL, *wbuf = NULL;
  wchar_t *wstr = NULL;
  int rval = 0, c = 0, ignore_ws = 0;
  va_list arg;
  unsigned char fc;
  unsigned int npos;
  int width, flags, base = 0, errno_sv;
  size_t wbuf_cur_sz, read_in_sv, new_sz, n;
  char seen_dot, seen_exp, is_neg, not_in;
  char *tmp_wbuf_ptr, buf[MB_LEN_MAX];
  const char *lc_decimal_point, *lc_thousands_sep;
  mbstate_t state, cstate;
  union {
    unsigned long long ull;
    unsigned long ul;
    long long ll;
    long l;
  } cv_val;

  arg = argp;

  if (!s || s->fp == NULL || !format)
    {
      errno = EINVAL;
      return EOF;
    }

  memset (&state, 0, sizeof (state));

  lc_decimal_point = localeconv()->decimal_point;
  lc_thousands_sep = localeconv()->thousands_sep;
  if (lc_thousands_sep != NULL && *lc_thousands_sep == 0)
    lc_thousands_sep = NULL;

  while (*f != 0)
    {
      if (!isascii ((unsigned char) *f))
	{
	  int len;

	  if ((len = mbrlen (f, strlen (f), &state)) > 0)
	    {
	      do
		{
		  if ((c = in_ch (s, &read_in)) == EOF || c != (unsigned char) *f++)
		    {
		      back_ch (c, s, &read_in, 1);
		      return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);
		    }
		}
	      while (--len > 0);

	      continue;
	    }
	}

      fc = *f++;
      if (fc != '%')
        {
          if (isspace (fc))
            ignore_ws = 1;
          else
	    {
	      if ((c = in_ch (s, &read_in)) == EOF)
		return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);

	      if (ignore_ws)
		{
		  ignore_ws = 0;
		  if (isspace (c))
		    {
		      do
			{
			  if ((c = in_ch (s, &read_in)) == EOF)
			    return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);
			}
		      while (isspace (c));
		    }
		}

	      if (c != fc)
		{
		  back_ch (c, s, &read_in, 0);
		  return cleanup_return (rval, &gcollect, pstr, &wbuf);
		}
	    }

	  continue;
	}

      width = flags = 0;
      npos = 0;
      wbuf_cur_sz = 0;

      if (isdigit ((unsigned char) *f))
	{
	  const char *svf = f;
	  npos = (unsigned char) *f++ - '0';
	  while (isdigit ((unsigned char) *f))
	    npos = npos * 10 + ((unsigned char) *f++ - '0');
	  if (*f != '$')
	    {
	      npos = 0;
	      f = svf;
	    }
	  else
	    f++;
	}

      do
	{
	  if (*f == '*')
	    flags |= IS_SUPPRESSED;
	  else if (*f == '\'')
	    {
	      if (lc_thousands_sep)
		flags |= USE_GROUP;
	    }
	  else if (*f == 'I')
	    {
	      /* we don't support locale's digits (i18N), but ignore it for now silently.  */
	      ;
#ifdef _WIN32
              if (f[1] == '6' && f[2] == '4')
                {
		  flags |= IS_LL | IS_L;
		  f += 2;
		}
	      else if (f[1] == '3' && f[2] == '2')
		{
		  flags |= IS_L;
		  f += 2;
		}
	      else
	        {
#ifdef _WIN64
		  flags |= IS_LL | IS_L;
#else
		  flags |= IS_L;
#endif
		}
#endif
	    }
	  else
	    break;
	  ++f;
        }
      while (1);

      while (isdigit ((unsigned char) *f))
	width = width * 10 + ((unsigned char) *f++ - '0');

      if (!width)
	width = -1;

      switch (*f)
	{
	case 'h':
	  ++f;
	  flags |= (*f == 'h' ? IS_C : IS_S);
	  if (*f == 'h')
	    ++f;
	  break;
	case 'l':
	  ++f;
	  flags |= (*f == 'l' ? IS_LL : 0) | IS_L;
	  if (*f == 'l')
	    ++f;
	  break;
	case 'q': case 'L':
	  ++f;
	  flags |= IS_LL | IS_L;
	  break;
	case 'a':
	  if (f[1] != 's' && f[1] != 'S' && f[1] != '[')
	    break;
	  ++f;
	  flags |= USE_GNU_ALLOC;
	  break;
	case 'm':
	  flags |= USE_POSIX_ALLOC;
	  ++f;
	  if (*f == 'l')
	    {
	      flags |= IS_L;
	      f++;
	    }
	  break;
	case 'z':
#ifdef _WIN64
	  flags |= IS_LL | IS_L;
#else
	  flags |= IS_L;
#endif
	  ++f;
	  break;
	case 'j':
	  if (sizeof (uintmax_t) > sizeof (unsigned long))
	    flags |= IS_LL;
	  else if (sizeof (uintmax_t) > sizeof (unsigned int))
	    flags |= IS_L;
	  ++f;
	  break;
	case 't':
#ifdef _WIN64
	  flags |= IS_LL;
#else
	  flags |= IS_L;
#endif
	  ++f;
	  break;
	case 0:
	  return cleanup_return (rval, &gcollect, pstr, &wbuf);
	default:
	  break;
	}

      if (*f == 0)
	return cleanup_return (rval, &gcollect, pstr, &wbuf);

      fc = *f++;
      if (ignore_ws || (fc != '[' && fc != 'c' && fc != 'C' && fc != 'n'))
	{
	  errno_sv = errno;
	  errno = 0;
	  do
	    {
	      if ((c == EOF || (c = in_ch (s, &read_in)) == EOF)
	          && errno == EINTR)
		return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);
	    }
	  while (isspace (c));

	  ignore_ws = 0;
	  errno = errno_sv;
	  back_ch (c, s, &read_in, 0);
	}

      switch (fc)
        {
        case 'c':
          if ((flags & IS_L) != 0)
            fc = 'C';
          break;
        case 's':
          if ((flags & IS_L) != 0)
            fc = 'S';
          break;
        }

      switch (fc)
	{
	case '%':
	  if ((c = in_ch (s, &read_in)) == EOF)
	    return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);
	  if (c != fc)
	    {
	      back_ch (c, s, &read_in, 1);
	      return cleanup_return (rval, &gcollect, pstr, &wbuf);
	    }
	  break;

	case 'n':
	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      if ((flags & IS_LL) != 0)
		*(npos != 0 ? (long long *) get_va_nth (argp, npos) : va_arg (arg, long long *)) = read_in;
	      else if ((flags & IS_L) != 0)
		*(npos != 0 ? (long *) get_va_nth (argp, npos) : va_arg (arg, long *)) = read_in;
	      else if ((flags & IS_S) != 0)
		*(npos != 0 ? (short *) get_va_nth (argp, npos) : va_arg (arg, short *)) = read_in;
	      else if ((flags & IS_C) != 0)
	        *(npos != 0 ? (char *) get_va_nth (argp, npos) : va_arg (arg, char *)) = read_in;
	      else
		*(npos != 0 ? (int *) get_va_nth (argp, npos) : va_arg (arg, int *)) = read_in;
	    }
	  break;

	case 'c':
	  if (width == -1)
	    width = 1;

	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      if ((flags & IS_ALLOC_USED) != 0)
		{
		  if (npos != 0)
		    pstr = (char **) get_va_nth (argp, npos);
		  else
		    pstr = va_arg (arg, char **);

		  if (!pstr)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);

		  str_sz = (width > 1024 ? 1024 : width);
		  if ((str = *pstr = (char *) malloc (str_sz)) == NULL)
		    return cleanup_return (((flags & USE_POSIX_ALLOC) != 0 ? EOF : rval), &gcollect, pstr, &wbuf);

		  gcollect = resize_gcollect (gcollect);
		  gcollect->ptrs[gcollect->count++] = pstr;
		}
	      else
		{
		  if (npos != 0)
		    str = (char *) get_va_nth (argp, npos);
		  else
		    str = va_arg (arg, char *);
		  if (!str)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);
		}
	    }

	  if ((c = in_ch (s, &read_in)) == EOF)
	    return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);

	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      do
		{
		  if ((flags & IS_ALLOC_USED) != 0 && str == (*pstr + str_sz))
		    {
		      new_sz = str_sz + (str_sz >= width ? width - 1 : str_sz);
		      while ((str = (char *) realloc (*pstr, new_sz)) == NULL
			     && new_sz > (size_t) (str_sz + 1))
			new_sz = str_sz + 1;
		      if (!str)
			{
			  release_ptrs (&gcollect, &wbuf);
			  return EOF;
			}
		      *pstr = str;
		      str += str_sz;
		      str_sz = new_sz;
		    }
		  *str++ = c;
		}
	      while (--width > 0 && (c = in_ch (s, &read_in)) != EOF);
	    }
	  else
	    while (--width > 0 && (c = in_ch (s, &read_in)) != EOF);

	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      optimize_alloc (pstr, str, str_sz);
	      pstr = NULL;
	      ++rval;
	    }

	  break;

	case 'C':
	  if (width == -1)
	    width = 1;

	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      if ((flags & IS_ALLOC_USED) != 0)
		{
		  if (npos != 0)
		    pstr = (char **) get_va_nth (argp, npos);
		  else
		    pstr = va_arg (arg, char **);

		  if (!pstr)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);
		  str_sz = (width > 1024 ? 1024 : width);
		  *pstr = (char *) malloc (str_sz * sizeof (wchar_t));
		  if ((wstr = (wchar_t *) *pstr) == NULL)
		    return cleanup_return (((flags & USE_POSIX_ALLOC) != 0 ? EOF : rval), &gcollect, pstr, &wbuf);
		  gcollect = resize_gcollect (gcollect);
		  gcollect->ptrs[gcollect->count++] = pstr;
		}
	      else
		{
		  if (npos != 0)
		    wstr = (wchar_t *) get_va_nth (argp, npos);
		  else
		    wstr = va_arg (arg, wchar_t *);
		  if (!wstr)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);
		}
	    }

	  if ((c = in_ch (s, &read_in)) == EOF)
	    return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);

	  memset (&cstate, 0, sizeof (cstate));

	  do
	    {
	      buf[0] = c;

	      if ((flags & IS_SUPPRESSED) == 0 && (flags & IS_ALLOC_USED) != 0
		  && wstr == ((wchar_t *) *pstr + str_sz))
		{
		  new_sz = str_sz + (str_sz > width ? width - 1 : str_sz);

		  while ((wstr = (wchar_t *) realloc (*pstr, new_sz * sizeof (wchar_t))) == NULL
			 && new_sz > (size_t) (str_sz + 1))
		    new_sz = str_sz + 1;
		  if (!wstr)
		    {
		      release_ptrs (&gcollect, &wbuf);
		      return EOF;
		    }
		  *pstr = (char *) wstr;
		  wstr += str_sz;
		  str_sz = new_sz;
		}

	      while (1)
		{
		  n = mbrtowc ((flags & IS_SUPPRESSED) == 0 ? wstr : NULL, buf, 1, &cstate);

		  if (n == (size_t) -2)
		    {
		      if ((c = in_ch (s, &read_in)) == EOF)
			{
			  errno = EILSEQ;
			  return cleanup_return (rval, &gcollect, pstr, &wbuf);
			}

		      buf[0] = c;
		      continue;
		    }

		  if (n != 1)
		    {
			errno = EILSEQ;
			return cleanup_return (rval, &gcollect, pstr, &wbuf);
		    }
		  break;
		}

	      ++wstr;
	    }
	  while (--width > 0 && (c = in_ch (s, &read_in)) != EOF);

	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      optimize_alloc (pstr, (char *) wstr, str_sz * sizeof (wchar_t));
	      pstr = NULL;
	      ++rval;
	    }
	  break;

	case 's':
	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      if ((flags & IS_ALLOC_USED) != 0)
		{
		 if (npos != 0)
		   pstr = (char **) get_va_nth (argp, npos);
		 else
		   pstr = va_arg (arg, char **);

		  if (!pstr)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);

		  str_sz = 100;
		  if ((str = *pstr = (char *) malloc (100)) == NULL)
		    return cleanup_return (((flags & USE_POSIX_ALLOC) != 0 ? EOF : rval), &gcollect, pstr, &wbuf);
		  gcollect = resize_gcollect (gcollect);
		  gcollect->ptrs[gcollect->count++] = pstr;
		}
	      else
		{
		  if (npos != 0)
		    str = (char *) get_va_nth (argp, npos);
		  else
		    str = va_arg (arg, char *);
		  if (!str)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);
		}
	    }

	  if ((c = in_ch (s, &read_in)) == EOF)
	    return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);

	  do
	    {
	      if (isspace (c))
		{
		  back_ch (c, s, &read_in, 1);
		  break;
		}

	      if ((flags & IS_SUPPRESSED) == 0)
		{
		  *str++ = c;
		  if ((flags & IS_ALLOC_USED) != 0 && str == (*pstr + str_sz))
		    {
		      new_sz = str_sz * 2;

		      while ((str = (char *) realloc (*pstr, new_sz)) == NULL
			     && new_sz > (size_t) (str_sz + 1))
			new_sz = str_sz + 1;
		      if (!str)
			{
			  if ((flags & USE_POSIX_ALLOC) == 0)
			    {
			      (*pstr)[str_sz - 1] = 0;
			      pstr = NULL;
			      ++rval;
			    }
			  return cleanup_return (((flags & USE_POSIX_ALLOC) != 0 ? EOF : rval), &gcollect, pstr, &wbuf);
			}
		      *pstr = str;
		      str += str_sz;
		      str_sz = new_sz;
		    }
		}
	    }
	  while ((width <= 0 || --width > 0) && (c = in_ch (s, &read_in)) != EOF);

	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      *str++ = 0;
	      optimize_alloc (pstr, str, str_sz);
	      pstr = NULL;
	      ++rval;
	    }
	  break;

	case 'S':
	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      if ((flags & IS_ALLOC_USED) != 0)
		{
		  if (npos != 0)
		    pstr = (char **) get_va_nth (argp, npos);
		  else
		    pstr = va_arg (arg, char **);

		  if (!pstr)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);

		  str_sz = 100;
		  *pstr = (char *) malloc (100 * sizeof (wchar_t));
		  if ((wstr = (wchar_t *) *pstr) == NULL)
		    return cleanup_return (((flags & USE_POSIX_ALLOC) != 0 ? EOF : rval), &gcollect, pstr, &wbuf);
		  gcollect = resize_gcollect (gcollect);
		  gcollect->ptrs[gcollect->count++] = pstr;
		}
	      else
		{
		  if (npos != 0)
		    wstr = (wchar_t *) get_va_nth (argp, npos);
		  else
		    wstr = va_arg (arg, wchar_t *);
		  if (!wstr)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);
		}
	    }

	  if ((c = in_ch (s, &read_in)) == EOF)
	    return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);

	  memset (&cstate, 0, sizeof (cstate));

	  do
	    {
	      if (isspace (c))
		{
		  back_ch (c, s, &read_in, 1);
		  break;
		}

	      buf[0] = c;

	      while (1)
		{
		  n = mbrtowc ((flags & IS_SUPPRESSED) == 0 ? wstr : NULL, buf, 1, &cstate);

		  if (n == (size_t) -2)
		    {
		      if ((c = in_ch (s, &read_in)) == EOF)
			{
			  errno = EILSEQ;
			  return cleanup_return (rval, &gcollect, pstr, &wbuf);
			}

		      buf[0] = c;
		      continue;
		    }

		  if (n != 1)
		    {
		      errno = EILSEQ;
		      return cleanup_return (rval, &gcollect, pstr, &wbuf);
		    }

		  ++wstr;
		  break;
		}

	      if ((flags & IS_SUPPRESSED) == 0 && (flags & IS_ALLOC_USED) != 0
		  && wstr == ((wchar_t *) *pstr + str_sz))
		{
		  new_sz = str_sz * 2;
		  while ((wstr = (wchar_t *) realloc (*pstr, new_sz * sizeof (wchar_t))) == NULL
			 && new_sz > (size_t) (str_sz + 1))
		    new_sz = str_sz + 1;
		  if (!wstr)
		    {
		      if ((flags & USE_POSIX_ALLOC) == 0)
			{
			  ((wchar_t *) (*pstr))[str_sz - 1] = 0;
			  pstr = NULL;
			  ++rval;
			}
		      return cleanup_return (((flags & USE_POSIX_ALLOC) != 0 ? EOF : rval), &gcollect, pstr, &wbuf);
		    }
		  *pstr = (char *) wstr;
		  wstr += str_sz;
		  str_sz = new_sz;
		}
	    }
	  while ((width <= 0 || --width > 0) && (c = in_ch (s, &read_in)) != EOF);

	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      *wstr++ = 0;
	      optimize_alloc (pstr, (char *) wstr, str_sz * sizeof (wchar_t));
	      pstr = NULL;
	      ++rval;
	    }
	  break;

	case 'd': case 'i':
	case 'o': case 'p':
	case 'u':
	case 'x': case 'X':
	  switch (fc)
	    {
	    case 'd':
	      flags |= IS_SIGNED_NUM;
	      base = 10;
	      break;
	    case 'i':
	      flags |= IS_SIGNED_NUM;
	      base = 0;
	      break;
	    case 'o':
	      base = 8;
	      break;
	    case 'p':
	      base = 16;
	      flags &= ~(IS_S | IS_LL | IS_L);
    #ifdef _WIN64
	      flags |= IS_LL;
    #endif
	      flags |= IS_L | IS_POINTER;
	      break;
	    case 'u':
	      base = 10;
	      break;
	    case 'x': case 'X':
	      base = 16;
	      break;
	    }

	  if ((c = in_ch (s, &read_in)) == EOF)
	    return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);
	  if (c == '+' || c == '-')
	    {
	      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
	      wbuf[wbuf_cur_sz++] = c;
	      if (width > 0)
		--width;
	      c = in_ch (s, &read_in);
	    }
	  if (width != 0 && c == '0')
	    {
	      if (width > 0)
		--width;

	      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
	      wbuf[wbuf_cur_sz++] = c;
	      c = in_ch (s, &read_in);

	      if (width != 0 && tolower (c) == 'x')
		{
		  if (!base)
		    base = 16;
		  if (base == 16)
		    {
		      if (width > 0)
			--width;
		      c = in_ch (s, &read_in);
		    }
		}
	      else if (!base)
		base = 8;
	    }

	  if (!base)
	    base = 10;

	  while (c != EOF && width != 0)
	    {
	      if (base == 16)
		{
		  if (!isxdigit (c))
		    break;
		}
	      else if (!isdigit (c) || (int) (c - '0') >= base)
		{
		  const char *p = lc_thousands_sep;
		  int remain;

		  if (base != 10 || (flags & USE_GROUP) == 0)
		    break;
		  remain = width > 0 ? width : INT_MAX;
		  while ((unsigned char) *p == c && remain >= 0)
		    {
		      /* As our conversion routines aren't supporting thousands
			 separators, we are filtering them here.  */

		      ++p;
		      if (*p == 0 || !remain || (c = in_ch (s, &read_in)) == EOF)
			break;
		      --remain;
		    }

		  if (*p != 0)
		    {
		      if (p > lc_thousands_sep)
			{
			  back_ch (c, s, &read_in, 0);
			  while (--p > lc_thousands_sep)
			    back_ch ((unsigned char) *p, s, &read_in, 1);
			  c = (unsigned char) *p;
			}
		      break;
		    }

		  if (width > 0)
		    width = remain;
		  --wbuf_cur_sz;
		}
	      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
	      wbuf[wbuf_cur_sz++] = c;
	      if (width > 0)
		--width;

	      c = in_ch (s, &read_in);
	    }

	  if (!wbuf_cur_sz || (wbuf_cur_sz == 1 && (wbuf[0] == '+' || wbuf[0] == '-')))
	    {
	      if (!wbuf_cur_sz && (flags & IS_POINTER) != 0
	          && match_string (s, &read_in, &c, "(nil)"))
		{
		  wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
		  wbuf[wbuf_cur_sz++] = '0';
		}
	      else
		{
		  back_ch (c, s, &read_in, 0);
		  return cleanup_return (rval, &gcollect, pstr, &wbuf);
		}
	    }
	  else
	    back_ch (c, s, &read_in, 0);

	  wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
	  wbuf[wbuf_cur_sz++] = 0;

	  if ((flags & IS_LL))
	    {
	      if (flags & IS_SIGNED_NUM)
		cv_val.ll = strtoll (wbuf, &tmp_wbuf_ptr, base/*, flags & USE_GROUP*/);
	      else
		cv_val.ull = strtoull (wbuf, &tmp_wbuf_ptr, base);
	    }
	  else
	    {
	      if (flags & IS_SIGNED_NUM)
		cv_val.l = strtol (wbuf, &tmp_wbuf_ptr, base/*, flags & USE_GROUP*/);
	      else
		cv_val.ul = strtoul (wbuf, &tmp_wbuf_ptr, base);
	    }
	  if (wbuf == tmp_wbuf_ptr)
	    return cleanup_return (rval, &gcollect, pstr, &wbuf);

	  if ((flags & IS_SUPPRESSED) == 0)
	    {
	      if ((flags & IS_SIGNED_NUM) != 0)
		{
		  if ((flags & IS_LL) != 0)
		    *(npos != 0 ? (long long *) get_va_nth (argp, npos) : va_arg (arg, long long *)) = cv_val.ll;
		  else if ((flags & IS_L) != 0)
		    *(npos != 0 ? (long *) get_va_nth (argp, npos) : va_arg (arg, long *)) = cv_val.l;
		  else if ((flags & IS_S) != 0)
		    *(npos != 0 ? (short *) get_va_nth (argp, npos) : va_arg (arg, short *)) = (short) cv_val.l;
		  else if ((flags & IS_C) != 0)
		    *(npos != 0 ? (signed char *) get_va_nth (argp, npos) : va_arg (arg, signed char *)) = (signed char) cv_val.ul;
		  else
		    *(npos != 0 ? (int *) get_va_nth (argp, npos) : va_arg (arg, int *)) = (int) cv_val.l;
		}
	      else
		{
		  if ((flags & IS_LL) != 0)
		    *(npos != 0 ? (unsigned long long *) get_va_nth (argp, npos) : va_arg (arg, unsigned long long *)) = cv_val.ull;
		  else if ((flags & IS_L) != 0)
		    *(npos != 0 ? (unsigned long *) get_va_nth (argp, npos) : va_arg (arg, unsigned long *)) = cv_val.ul;
		  else if ((flags & IS_S) != 0)
		    *(npos != 0 ? (unsigned short *) get_va_nth (argp, npos) : va_arg (arg, unsigned short *))
		      = (unsigned short) cv_val.ul;
		  else if ((flags & IS_C) != 0)
		    *(npos != 0 ? (unsigned char *) get_va_nth (argp, npos) : va_arg (arg, unsigned char *)) = (unsigned char) cv_val.ul;
		  else
		    *(npos != 0 ? (unsigned int *) get_va_nth (argp, npos) : va_arg (arg, unsigned int *)) = (unsigned int) cv_val.ul;
		}
	      ++rval;
	    }
	  break;

	case 'e': case 'E':
	case 'f': case 'F':
	case 'g': case 'G':
	case 'a': case 'A':
	  if (width > 0)
	    --width;
	  if ((c = in_ch (s, &read_in)) == EOF)
	    return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);

	  seen_dot = seen_exp = 0;
	  is_neg = (c == '-' ? 1 : 0);

	  if (c == '-' || c == '+')
	    {
	      if (width == 0 || (c = in_ch (s, &read_in)) == EOF)
		return cleanup_return (rval, &gcollect, pstr, &wbuf);
	      if (width > 0)
		--width;
	    }

	  if (tolower (c) == 'n')
	    {
	      const char *match_txt = "nan";

	      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
	      wbuf[wbuf_cur_sz++] = c;

	      ++match_txt;
	      do
		{
		  if (width == 0 || (c = in_ch (s, &read_in)) == EOF || tolower (c) != match_txt[0])
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);

		  if (width > 0)
		    --width;

		  wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
		  wbuf[wbuf_cur_sz++] = c;
		  ++match_txt;
		}
	      while (*match_txt != 0);
	    }
	  else if (tolower (c) == 'i')
	    {
	      const char *match_txt = "inf";

	      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
	      wbuf[wbuf_cur_sz++] = c;

	      ++match_txt;
	      do
		{
		  if (width == 0 || (c = in_ch (s, &read_in)) == EOF || tolower (c) != match_txt[0])
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);
		  if (width > 0)
		    --width;

		  wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
		  wbuf[wbuf_cur_sz++] = c;
		  ++match_txt;
		}
	      while (*match_txt != 0);

	      if (width != 0 && (c = in_ch (s, &read_in)) != EOF && tolower (c) == 'i')
		{
		  match_txt = "inity";

		  if (width > 0)
		    --width;

		  wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
		  wbuf[wbuf_cur_sz++] = c;
		  ++match_txt;

		  do
		    {
		      if (width == 0 || (c = in_ch (s, &read_in)) == EOF || tolower (c) != match_txt[0])
			return cleanup_return (rval, &gcollect, pstr, &wbuf);
		      if (width > 0)
			--width;

		      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
		      wbuf[wbuf_cur_sz++] = c;
		      ++match_txt;
		    }
		  while (*match_txt != 0);
		}
	      else if (width != 0 && c != EOF)
	        back_ch (c, s, &read_in, 0);
	    }
	  else
	    {
	      not_in = 'e';
	      if (width != 0 && c == '0')
		{
		  wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
		  wbuf[wbuf_cur_sz++] = c;

		  c = in_ch (s, &read_in);
		  if (width > 0)
		    --width;
		  if (width != 0 && tolower (c) == 'x')
		    {
		      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
		      wbuf[wbuf_cur_sz++] = c;

		      flags |= IS_HEX_FLOAT;
		      not_in = 'p';

		      flags &= ~USE_GROUP;
		      c = in_ch (s, &read_in);
		      if (width > 0)
			--width;
		    }
		}

	      while (1)
		{
		  if (isdigit (c) || (!seen_exp && (flags & IS_HEX_FLOAT) != 0 && isxdigit (c))
		      || (seen_exp && wbuf[wbuf_cur_sz - 1] == not_in && (c == '-' || c == '+')))
		    {
		      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
		      wbuf[wbuf_cur_sz++] = c;
		    }
		  else if (wbuf_cur_sz > 0 && !seen_exp && (char) tolower (c) == not_in)
		    {
		      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
		      wbuf[wbuf_cur_sz++] = not_in;
		      seen_exp = seen_dot = 1;
		    }
		  else
		    {
		      const char *p = lc_decimal_point;
		      int remain = width > 0 ? width : INT_MAX;

		      if (! seen_dot)
			{
			  while ((unsigned char) *p == c && remain >= 0)
			    {
			      ++p;
			      if (*p == 0 || !remain || (c = in_ch (s, &read_in)) == EOF)
				break;
			      --remain;
			    }
			}

		      if (*p == 0)
			{
			  for (p = lc_decimal_point; *p != 0; ++p)
			    {
			      wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
			      wbuf[wbuf_cur_sz++] = (unsigned char) *p;
			    }
			  if (width > 0)
			    width = remain;
			  seen_dot = 1;
			}
		      else
			{
			  const char *pp = lc_thousands_sep;

			  if (!seen_dot && (flags & USE_GROUP) != 0)
			    {
			      while ((pp - lc_thousands_sep) < (p - lc_decimal_point)
				     && *pp == lc_decimal_point[(pp - lc_thousands_sep)])
				++pp;
			      if ((pp - lc_thousands_sep) == (p - lc_decimal_point))
				{
				  while ((unsigned char) *pp == c && remain >= 0)
				    {
				      ++pp;
				      if (*pp == 0 || !remain || (c = in_ch (s, &read_in)) == EOF)
					break;
				      --remain;
				    }
				}
			    }

			  if (pp != NULL && *pp == 0)
			    {
			      /* As our conversion routines aren't supporting thousands
				 separators, we are filtering them here.  */
			      if (width > 0)
				width = remain;
			    }
			  else
			    {
			      back_ch (c, s, &read_in, 0);
			      break;
			    }
			}
		    }

		  if (width == 0 || (c = in_ch (s, &read_in)) == EOF)
		    break;

		  if (width > 0)
		    --width;
		}

	      if (!wbuf_cur_sz || ((flags & IS_HEX_FLOAT) != 0 && wbuf_cur_sz == 2))
		return cleanup_return (rval, &gcollect, pstr, &wbuf);
	    }

	  wbuf = resize_wbuf (wbuf_cur_sz, &wbuf_max_sz, wbuf);
	  wbuf[wbuf_cur_sz++] = 0;

	  if ((flags & IS_LL) != 0)
	    {
	      long double ld;
	      ld = __mingw_strtold (wbuf, &tmp_wbuf_ptr/*, flags & USE_GROUP*/);
	      if ((flags & IS_SUPPRESSED) == 0 && tmp_wbuf_ptr != wbuf)
	        *(npos != 0 ? (long double *) get_va_nth (argp, npos) : va_arg (arg, long double *)) = is_neg ? -ld : ld;
	    }
	  else if ((flags & IS_L) != 0)
	    {
	      double d;
	      d = (double) __mingw_strtold (wbuf, &tmp_wbuf_ptr/*, flags & USE_GROUP*/);
	      if ((flags & IS_SUPPRESSED) == 0 && tmp_wbuf_ptr != wbuf)
		*(npos != 0 ? (double *) get_va_nth (argp, npos) : va_arg (arg, double *)) = is_neg ? -d : d;
	    }
	  else
	    {
	      float d = __mingw_strtof (wbuf, &tmp_wbuf_ptr/*, flags & USE_GROUP*/);
	      if ((flags & IS_SUPPRESSED) == 0 && tmp_wbuf_ptr != wbuf)
		*(npos != 0 ? (float *) get_va_nth (argp, npos) : va_arg (arg, float *)) = is_neg ? -d : d;
	    }

	  if (wbuf == tmp_wbuf_ptr)
	    return cleanup_return (rval, &gcollect, pstr, &wbuf);

	  if ((flags & IS_SUPPRESSED) == 0)
	    ++rval;
	  break;

	case '[':
	  if ((flags & IS_L) != 0)
	    {
	      if ((flags & IS_SUPPRESSED) == 0)
		{
		  if ((flags & IS_ALLOC_USED) != 0)
		    {
		      if (npos != 0)
			pstr = (char **) get_va_nth (argp, npos);
		      else
			pstr = va_arg (arg, char **);

		      if (!pstr)
			return cleanup_return (rval, &gcollect, pstr, &wbuf);

		      str_sz = 100;
		      *pstr = (char *) malloc (100 * sizeof (wchar_t));

		      if ((wstr = (wchar_t *) *pstr) == NULL)
			return cleanup_return (((flags & USE_POSIX_ALLOC) != 0 ? EOF : rval), &gcollect, pstr, &wbuf);
		      gcollect = resize_gcollect (gcollect);
		      gcollect->ptrs[gcollect->count++] = pstr;
		    }
		  else
		    {
		      if (npos != 0)
			wstr = (wchar_t *) get_va_nth (argp, npos);
		      else
			wstr = va_arg (arg, wchar_t *);
		      if (!wstr)
			return cleanup_return (rval, &gcollect, pstr, &wbuf);
		    }
		}
	    }
	  else if ((flags & IS_SUPPRESSED) == 0)
	    {
	      if ((flags & IS_ALLOC_USED) != 0)
		{
		  if (npos != 0)
		    pstr = (char **) get_va_nth (argp, npos);
		  else
		    pstr = va_arg (arg, char **);

		  if (!pstr)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);

		  str_sz = 100;
		  if ((str = *pstr = (char *) malloc (100)) == NULL)
		    return cleanup_return (((flags & USE_POSIX_ALLOC) != 0 ? EOF : rval), &gcollect, pstr, &wbuf);

		  gcollect = resize_gcollect (gcollect);
		  gcollect->ptrs[gcollect->count++] = pstr;
		}
	      else
		{
		  if (npos != 0)
		    str = (char *) get_va_nth (argp, npos);
		  else
		    str = va_arg (arg, char *);
		  if (!str)
		    return cleanup_return (rval, &gcollect, pstr, &wbuf);
		}
	    }

	  not_in = (*f == '^' ? 1 : 0);
	  if (*f == '^')
	    f++;

	  if (width < 0)
	    width = INT_MAX;

	  if (wbuf_max_sz < 256)
	    {
	      wbuf_max_sz = 256;
	      if (wbuf)
	        free (wbuf);
	      wbuf = (char *) malloc (wbuf_max_sz);
	    }
	  memset (wbuf, 0, 256);

	  fc = *f;
	  if (fc == ']' || fc == '-')
	    {
	      wbuf[fc] = 1;
	      ++f;
	    }

	  while ((fc = *f++) != 0 && fc != ']')
	    {
	      if (fc == '-' && *f != 0 && *f != ']' && (unsigned char) f[-2] <= (unsigned char) *f)
		{
		  for (fc = (unsigned char) f[-2]; fc < (unsigned char) *f; ++fc)
		    wbuf[fc] = 1;
		}
	      else
		wbuf[fc] = 1;
	    }

	  if (!fc)
	    return cleanup_return (rval, &gcollect, pstr, &wbuf);

	  if ((flags & IS_L) != 0)
	    {
	      read_in_sv = read_in;
	      cnt = 0;

	      if ((c = in_ch (s, &read_in)) == EOF)
		return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);

	      memset (&cstate, 0, sizeof (cstate));

	      do
		{
		  if (wbuf[c] == not_in)
		    {
		      back_ch (c, s, &read_in, 1);
		      break;
		    }

		  if ((flags & IS_SUPPRESSED) == 0)
		    {
		      buf[0] = c;
		      n = mbrtowc (wstr, buf, 1, &cstate);

		      if (n == (size_t) -2)
			{
			  ++cnt;
			  continue;
			}
		      cnt = 0;

		      ++wstr;
		      if ((flags & IS_ALLOC_USED) != 0 && wstr == ((wchar_t *) *pstr + str_sz))
			{
			  new_sz = str_sz * 2;
			  while ((wstr = (wchar_t *) realloc (*pstr, new_sz * sizeof (wchar_t))) == NULL
			  	 && new_sz > (size_t) (str_sz + 1))
			    new_sz = str_sz + 1;
			  if (!wstr)
			    {
			      if ((flags & USE_POSIX_ALLOC) == 0)
				{
				  ((wchar_t *) (*pstr))[str_sz - 1] = 0;
				  pstr = NULL;
				  ++rval;
				}
			      else
				rval = EOF;
			      return cleanup_return (rval, &gcollect, pstr, &wbuf);
			    }
			  *pstr = (char *) wstr;
			  wstr += str_sz;
			  str_sz = new_sz;
			}
		    }

		  if (--width <= 0)
		    break;
		}
	      while ((c = in_ch (s, &read_in)) != EOF);

	      if (cnt != 0)
		{
		  errno = EILSEQ;
		  return cleanup_return (rval, &gcollect, pstr, &wbuf);
		}

	      if (read_in_sv == read_in)
		return cleanup_return (rval, &gcollect, pstr, &wbuf);


	      if ((flags & IS_SUPPRESSED) == 0)
		{
		  *wstr++ = 0;
		  optimize_alloc (pstr, (char *) wstr, str_sz * sizeof (wchar_t));
		  pstr = NULL;
		  ++rval;
		}
	    }
	  else
	    {
	      read_in_sv = read_in;

	      if ((c = in_ch (s, &read_in)) == EOF)
		return cleanup_return ((!rval ? EOF : rval), &gcollect, pstr, &wbuf);

	      do
		{
		  if (wbuf[c] == not_in)
		    {
		      back_ch (c, s, &read_in, 1);
		      break;
		    }

		  if ((flags & IS_SUPPRESSED) == 0)
		    {
		      *str++ = c;
		      if ((flags & IS_ALLOC_USED) != 0 && str == (*pstr + str_sz))
			{
			  new_sz = str_sz * 2;

			  while ((str = (char *) realloc (*pstr, new_sz)) == NULL
			         && new_sz > (size_t) (str_sz + 1))
			    new_sz = str_sz + 1;
			  if (!str)
			    {
			      if ((flags & USE_POSIX_ALLOC) == 0)
				{
				  (*pstr)[str_sz - 1] = 0;
				  pstr = NULL;
				  ++rval;
				}
			      else
			        rval = EOF;
			      return cleanup_return (rval, &gcollect, pstr, &wbuf);
			    }
			  *pstr = str;
			  str += str_sz;
			  str_sz = new_sz;
			}
		    }
		}
	      while (--width > 0 && (c = in_ch (s, &read_in)) != EOF);

	      if (read_in_sv == read_in)
		return cleanup_return (rval, &gcollect, pstr, &wbuf);

	      if ((flags & IS_SUPPRESSED) == 0)
		{
		  *str++ = 0;
		  optimize_alloc (pstr, str, str_sz);
		  pstr = NULL;
		  ++rval;
		}
	    }
	  break;

	default:
	  return cleanup_return (rval, &gcollect, pstr, &wbuf);
	}
    }

  if (ignore_ws)
    {
      while (isspace ((c = in_ch (s, &read_in))));
      back_ch (c, s, &read_in, 0);
    }

  return cleanup_return (rval, &gcollect, pstr, &wbuf);
}

int
__mingw_vfscanf (FILE *s, const char *format, va_list argp)
{
  _IFP ifp;
  memset (&ifp, 0, sizeof (_IFP));
  ifp.fp = s;
  return __mingw_sformat (&ifp, format, argp);
}

int
__mingw_vsscanf (const char *s, const char *format, va_list argp)
{
  _IFP ifp;
  memset (&ifp, 0, sizeof (_IFP));
  ifp.str = s;
  ifp.is_string = 1;
  return __mingw_sformat (&ifp, format, argp);
}

