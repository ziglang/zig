#include <windows.h>
#include <malloc.h>
#include <errno.h>
#include <msvcrt.h>
#include <io.h>

static errno_t __cdecl _int_umask_s (int, int *);
static errno_t __cdecl _stub (int, int *);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_umask_s))(int, int *) = 
 _stub;

static errno_t __cdecl
_stub (int m, int *pold)
{
  errno_t __cdecl (*f)(int, int *) = __MINGW_IMP_SYMBOL(_umask_s);

  if (f == _stub)
    {
	f = (errno_t __cdecl (*)(int, int *))
	    GetProcAddress (__mingw_get_msvcrt_handle (), "_umask_s");
	if (!f)
	  f = _int_umask_s;
	__MINGW_IMP_SYMBOL(_umask_s) = f;
    }
  return (*f)(m, pold);
}

errno_t __cdecl
_umask_s (int m, int *pold)
{
  return _stub (m, pold);
}

static errno_t __cdecl
_int_umask_s (int m, int *pold)
{
  if (!pold)
     {
        errno = EINVAL;
	return EINVAL;
     }
  *pold = _umask (m);
  return 0;
}
