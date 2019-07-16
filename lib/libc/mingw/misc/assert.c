/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>
#include <signal.h>

void __cdecl _wassert (const wchar_t *, const wchar_t *,unsigned);
void __cdecl _assert (const char *, const char *, unsigned);

void __cdecl
_assert (const char *_Message, const char *_File, unsigned _Line)
{
  wchar_t *m, *f;
  int i;
  m = (wchar_t *) malloc ((strlen (_Message) + 1) * sizeof (wchar_t));
  f = (wchar_t *) malloc ((strlen (_File) + 1) * sizeof (wchar_t));
  for (i = 0; _Message[i] != 0; i++)
    m[i] = ((wchar_t) _Message[i]) & 0xff;
  m[i] = 0;
  for (i = 0; _File[i] != 0; i++)
    f[i] = ((wchar_t) _File[i]) & 0xff;
  f[i] = 0;
  _wassert (m, f, _Line);
  free (m);
  free (f);
}
