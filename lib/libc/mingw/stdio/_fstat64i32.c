#define __CRT__NO_INLINE
#include <sys/stat.h>

int __cdecl _fstat64i32(int _FileDes,struct _stat64i32 *_Stat)
{
  struct _stat64 st;
  int ret=_fstat64(_FileDes,&st);
  if (ret == -1) {
    memset(_Stat,0,sizeof(struct _stat64i32));
    return -1;
  }
  _Stat->st_dev=st.st_dev;
  _Stat->st_ino=st.st_ino;
  _Stat->st_mode=st.st_mode;
  _Stat->st_nlink=st.st_nlink;
  _Stat->st_uid=st.st_uid;
  _Stat->st_gid=st.st_gid;
  _Stat->st_rdev=st.st_rdev;
  _Stat->st_size=(_off_t) st.st_size; /* 32bit size */
  _Stat->st_atime=st.st_atime;
  _Stat->st_mtime=st.st_mtime;
  _Stat->st_ctime=st.st_ctime;
  return ret;
}

