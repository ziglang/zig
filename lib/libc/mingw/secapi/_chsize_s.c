#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <io.h>

static errno_t __cdecl _int_chsize_s (int, long long);
static errno_t __cdecl _stub (int, long long);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_chsize_s))(int, long long) = 
 _stub;

static errno_t __cdecl
_stub (int fd, long long sz)
{
  errno_t __cdecl (*f)(int, long long) = __MINGW_IMP_SYMBOL(_chsize_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(int, long long))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_chsize_s");
	if (!f)
	  f = _int_chsize_s;
	__MINGW_IMP_SYMBOL(_chsize_s) = f;
    }
  return (*f)(fd, sz);
}

errno_t __cdecl
_chsize_s (int fd, long long sz)
{
  return _stub (fd, sz);
}

static errno_t __cdecl
_int_chsize_s (int fd, long long sz)
{
  if (sz > 0x7fffffffll)
    {
      /* We can't set file bigger as 2GB, so return EACCES.  */
      return (errno = EACCES);
    }
  if (!_chsize (fd, sz))
    return 0;
  return errno;
}
