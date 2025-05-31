/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <sys/stat.h>

/* When the file size does not fit into the st_size field:
 *           crtdll-msvcr90   msvcr100   msvcr110+
 * st_size      truncate         0           0
 * errno       no change     no change   EOVERFLOW
 * returns         0            -1          -1
 *
 * This file is used only for pre-msvcr80 builds,
 * So use the pre-msvcr80 behavior - truncate without error.
 */
int __cdecl _stat64i32(const char *_Name,struct _stat64i32 *_Stat)
{
  struct _stat64 st;
  int ret=_stat64(_Name,&st);
  if (ret != 0)
    return ret;
  _Stat->st_dev=st.st_dev;
  _Stat->st_ino=st.st_ino;
  _Stat->st_mode=st.st_mode;
  _Stat->st_nlink=st.st_nlink;
  _Stat->st_uid=st.st_uid;
  _Stat->st_gid=st.st_gid;
  _Stat->st_rdev=st.st_rdev;
  _Stat->st_size=(_off_t) st.st_size; /* truncate 64-bit st_size to 32-bit */
  _Stat->st_atime=st.st_atime;
  _Stat->st_mtime=st.st_mtime;
  _Stat->st_ctime=st.st_ctime;
  return 0;
}
int (__cdecl *__MINGW_IMP_SYMBOL(_stat64i32))(const char *, struct _stat64i32 *) = _stat64i32;
