#define __CRT__NO_INLINE
#include <io.h>
#include <string.h>

intptr_t __cdecl _findfirst64i32(const char *_Filename,struct _finddata64i32_t *_FindData)
{
  struct __finddata64_t fd;
  intptr_t ret = _findfirst64(_Filename,&fd);
  if (ret == -1) {
    memset(_FindData,0,sizeof(struct _finddata64i32_t));
    return -1;
  }
  _FindData->attrib=fd.attrib;
  _FindData->time_create=fd.time_create;
  _FindData->time_access=fd.time_access;
  _FindData->time_write=fd.time_write;
  _FindData->size=(_fsize_t) fd.size;
  strncpy(_FindData->name,fd.name,260);
  return ret;
}

