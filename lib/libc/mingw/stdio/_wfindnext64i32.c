#define __CRT__NO_INLINE
#include <io.h>
#include <string.h>

int __cdecl _wfindnext64i32(intptr_t _FindHandle,struct _wfinddata64i32_t *_FindData)
{
  struct _wfinddata64_t fd;
  int ret = _wfindnext64(_FindHandle,&fd);
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

