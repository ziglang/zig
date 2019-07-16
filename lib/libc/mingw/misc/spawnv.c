#include <process.h>

intptr_t __cdecl spawnv(int mode,const char *_Filename,char *const _ArgList[])
{
  return _spawnv(mode, _Filename,(const char *const *)_ArgList);
}
