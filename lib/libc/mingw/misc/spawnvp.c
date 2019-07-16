#include <process.h>

intptr_t __cdecl spawnvp(int mode,const char *_Filename,char *const _ArgList[])
{
  return _spawnvp(mode, _Filename,(const char *const *)_ArgList);
}
