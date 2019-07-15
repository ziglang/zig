#ifndef _SYS_STAT_H
#include <io/sys/stat.h>

#ifndef _ISOMAC
/* Now define the internal interfaces. */
extern int __stat (const char *__file, struct stat *__buf);
extern int __fstat (int __fd, struct stat *__buf);
extern int __lstat (const char *__file, struct stat *__buf);
extern int __chmod (const char *__file, __mode_t __mode);
libc_hidden_proto (__chmod)
extern int __fchmod (int __fd, __mode_t __mode);
extern __mode_t __umask (__mode_t __mask);
extern int __mkdir (const char *__path, __mode_t __mode);
libc_hidden_proto (__mkdir)
extern int __mknod (const char *__path,
		    __mode_t __mode, __dev_t __dev);
#if IS_IN (libc) || (IS_IN (rtld) && !defined NO_RTLD_HIDDEN)
hidden_proto (__fxstat)
hidden_proto (__fxstat64)
hidden_proto (__lxstat)
hidden_proto (__lxstat64)
hidden_proto (__xstat)
hidden_proto (__xstat64)
#endif
extern __inline__ int __stat (const char *__path, struct stat *__statbuf)
{
  return __xstat (_STAT_VER, __path, __statbuf);
}
libc_hidden_proto (__xmknod)
extern __inline__ int __mknod (const char *__path, __mode_t __mode,
			       __dev_t __dev)
{
  return __xmknod (_MKNOD_VER, __path, __mode, &__dev);
}
libc_hidden_proto (__xmknodat)

libc_hidden_proto (__fxstatat)
libc_hidden_proto (__fxstatat64)

# if IS_IN (rtld) && !defined NO_RTLD_HIDDEN
extern __typeof (__fxstatat64) __fxstatat64 attribute_hidden;
# endif

/* The `stat', `fstat', `lstat' functions have to be handled special since
   even while not compiling the library with optimization calls to these
   functions in the shared library must reference the `xstat' etc functions.
   We have to use macros but we cannot define them in the normal headers
   since on user level we must use real functions.  */
#define stat(fname, buf) __xstat (_STAT_VER, fname, buf)
#define lstat(fname, buf)  __lxstat (_STAT_VER, fname, buf)
#define __lstat(fname, buf)  __lxstat (_STAT_VER, fname, buf)
#define lstat64(fname, buf)  __lxstat64 (_STAT_VER, fname, buf)
#define __lstat64(fname, buf)  __lxstat64 (_STAT_VER, fname, buf)
#define stat64(fname, buf) __xstat64 (_STAT_VER, fname, buf)
#define fstat64(fd, buf) __fxstat64 (_STAT_VER, fd, buf)
#define __fstat64(fd, buf) __fxstat64 (_STAT_VER, fd, buf)
#define fstat(fd, buf) __fxstat (_STAT_VER, fd, buf)
#define __fstat(fd, buf) __fxstat (_STAT_VER, fd, buf)
#define __fstatat(dfd, fname, buf, flag) \
  __fxstatat (_STAT_VER, dfd, fname, buf, flag)
#define __fstatat64(dfd, fname, buf, flag) \
  __fxstatat64 (_STAT_VER, dfd, fname, buf, flag)
#endif
#endif
