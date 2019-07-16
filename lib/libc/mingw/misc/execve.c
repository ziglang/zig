#include <process.h>

int __cdecl execve(const char *_Filename,char *const _ArgList[],char *const _Env[])
{
  return _execve (_Filename, (const char *const *)_ArgList, (const char * const *)_Env);
}
