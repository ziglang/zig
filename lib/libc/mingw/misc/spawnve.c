#include <process.h>

intptr_t __cdecl spawnve(int mode,const char *_Filename,char *const _ArgList[],char *const _Env[])
{
  return _spawnve(mode, _Filename,(const char *const *)_ArgList,(const char *const *)_Env);
}
