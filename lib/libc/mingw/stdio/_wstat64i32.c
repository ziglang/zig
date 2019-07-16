#define __CRT__NO_INLINE
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

static wchar_t*
_mingw_no_trailing_slash (const wchar_t* _path)
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

int __cdecl _wstat64i32(const wchar_t *_Name,struct _stat64i32 *_Stat)
{
  struct _stat64 st;
  wchar_t *_path = _mingw_no_trailing_slash(_Name);
  
  int ret=_wstat64(_path,&st);

  if (_path != _Name)
    free(_path);

  if (ret == -1) {
    memset(_Stat,0,sizeof(struct _stat64i32));
    return -1;
  }
  _Stat->st_dev=st.st_dev;
  _Stat->st_ino=st.st_ino;
  _Stat->st_mode=st.st_mode;
  _Stat->st_nlink=st.st_nlink;
  _Stat->st_uid=st.st_uid;
  _Stat->st_gid=st.st_gid;
  _Stat->st_rdev=st.st_rdev;
  _Stat->st_size=(_off_t) st.st_size;
  _Stat->st_atime=st.st_atime;
  _Stat->st_mtime=st.st_mtime;
  _Stat->st_ctime=st.st_ctime;
  return ret;
}

