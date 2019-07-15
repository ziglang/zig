#define __CRT__NO_INLINE
#include <io.h>
#include <string.h>

intptr_t __cdecl _wfindfirst64i32(const wchar_t *_Filename,struct _wfinddata64i32_t *_FindData)
{
  struct _wfinddata64_t fd;
  intptr_t ret = _wfindfirst64(_Filename,&fd);
  if (ret == -1) {
    memset(_FindData,0,sizeof(struct _wfinddata64i32_t));
    return -1;
  }
  _FindData->attrib=fd.attrib;
  _FindData->time_create=fd.time_create;
  _FindData->time_access=fd.time_access;
  _FindData->time_write=fd.time_write;
  _FindData->size=(_fsize_t) fd.size;
  memcpy(_FindData->name,fd.name,260*sizeof(wchar_t));
  return ret;
}

