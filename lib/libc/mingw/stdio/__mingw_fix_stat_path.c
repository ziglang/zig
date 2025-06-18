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

char* __mingw_fix_stat_path (const char* _path);
char* __mingw_fix_stat_path (const char* _path)
{
  int len;
  char *p;

  p = (char*)_path;

  if (_path && *_path) {
    len = strlen (_path);

    /* Ignore X:\ */

    if (len <= 1 || ((len == 2 || len == 3) && _path[1] == ':'))
      return p;

    /* Check UNC \\abc\<name>\ */
    if ((_path[0] == '\\' || _path[0] == '/')
	&& (_path[1] == '\\' || _path[1] == '/'))
      {
	const char *r = &_path[2];
	while (*r != 0 && *r != '\\' && *r != '/')
	  ++r;
	if (*r != 0)
	  ++r;
	if (*r == 0)
	  return p;
	while (*r != 0 && *r != '\\' && *r != '/')
	  ++r;
	if (*r != 0)
	  ++r;
	if (*r == 0)
	  return p;
      }

    if (_path[len - 1] == '/' || _path[len - 1] == '\\')
      {
	p = (char*)malloc (len);
	memcpy (p, _path, len - 1);
	p[len - 1] = '\0';
      }
  }

  return p;
}
