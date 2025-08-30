/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <sys/stat.h>
#include <stdlib.h>

/**
 * Returns _path without trailing slash if any
 *
 * - if _path has no trailing slash, the function returns it
 * - if _path has a trailing slash, but is of the form C:/, then it returns it
 * - otherwise, the function creates a new string, which is a copy of _path
 *   without the trailing slash. It is then the responsibility of the caller
 *   to free it.
 */

wchar_t* __mingw_fix_wstat_path (const wchar_t* _path);
wchar_t* __mingw_fix_wstat_path (const wchar_t* _path)
{
  int len;
  wchar_t *p;

  p = (wchar_t*)_path;

  if (_path && *_path) {
    len = wcslen (_path);

    /* Ignore X:\ */

    if (len <= 1 || ((len == 2 || len == 3) && _path[1] == L':'))
      return p;

    /* Check UNC \\abc\<name>\ */
    if ((_path[0] == L'\\' || _path[0] == L'/')
	&& (_path[1] == L'\\' || _path[1] == L'/'))
      {
	const wchar_t *r = &_path[2];
	while (*r != 0 && *r != L'\\' && *r != L'/')
	  ++r;
	if (*r != 0)
	  ++r;
	if (*r == 0)
	  return p;
	while (*r != 0 && *r != L'\\' && *r != L'/')
	  ++r;
	if (*r != 0)
	  ++r;
	if (*r == 0)
	  return p;
      }

    if (_path[len - 1] == L'/' || _path[len - 1] == L'\\')
      {
	p = (wchar_t*)malloc (len * sizeof(wchar_t));
	memcpy (p, _path, (len - 1) * sizeof(wchar_t));
	p[len - 1] = L'\0';
      }
  }

  return p;
}
