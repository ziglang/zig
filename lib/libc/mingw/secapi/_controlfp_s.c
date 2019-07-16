#include <float.h>
#include <errno.h>
#include <windows.h>
#include <msvcrt.h>

static errno_t __cdecl _stub(
    unsigned int *currentControl,
    unsigned int newControl,
    unsigned int mask
);

errno_t __cdecl (*__MINGW_IMP_SYMBOL(_controlfp_s))(unsigned int *, unsigned int, unsigned int) = _stub;

errno_t __cdecl _controlfp_s(
    unsigned int *currentControl,
    unsigned int newControl,
    unsigned int mask
){
  return __MINGW_IMP_SYMBOL(_controlfp_s)(currentControl,newControl,mask);
}

static const unsigned int allflags = _MCW_DN | _MCW_EM | _MCW_IC | _MCW_RC | _MCW_PC;
static errno_t __cdecl _int_controlfp_s(
    unsigned int *currentControl,
    unsigned int newControl,
    unsigned int mask
){
  unsigned int cont;
  if(!(newControl & mask & ~allflags)){
    if (currentControl) *currentControl = _controlfp( 0, 0 );
    return EINVAL;
  }
  cont = _controlfp( newControl, mask );
  if(currentControl) *currentControl = cont;
  return 0;
}

static errno_t __cdecl _stub (
    unsigned int *currentControl,
    unsigned int newControl,
    unsigned int mask
)
{
  errno_t __cdecl (*f)(unsigned int *, unsigned int, unsigned int) = __MINGW_IMP_SYMBOL(_controlfp_s);

  if (f == _stub)
    {
        f = (errno_t __cdecl (*)(unsigned int *, unsigned int, unsigned int))
            GetProcAddress (__mingw_get_msvcrt_handle (), "_controlfp_s");
        if (!f)
          f = _int_controlfp_s;
        __MINGW_IMP_SYMBOL(_controlfp_s) = f;
    }
  return (*f)(currentControl, newControl, mask);
}

