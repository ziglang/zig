#ifndef _SYS_STAT_H
#include <io/sys/stat.h>

#ifndef _ISOMAC
# include <xstatver.h>
# include <struct___timespec64.h>
# include <struct_stat_time64.h>
# include <stdbool.h>

static inline bool
in_ino_t_range (__ino64_t v)
{
  __ino_t s = v;
  return s == v;
}

static inline bool
in_off_t_range (__off64_t v)
{
  __off_t s = v;
  return s == v;
}

static inline bool
in_blkcnt_t_range (__blkcnt64_t v)
{
  __blkcnt_t s = v;
  return s == v;
}

/* Now define the internal interfaces. */
extern int __stat (const char *__file, struct stat *__buf);
extern int __stat64 (const char *__file, struct stat64 *__buf);
extern int __fstat (int __fd, struct stat *__buf);
extern int __fstat64 (int __fd, struct stat64 *__buf);
extern int __lstat (const char *__file, struct stat *__buf);
extern int __lstat64 (const char *__file, struct stat64 *__buf);
extern int __fstatat (int dirfd, const char *pathname, struct stat *buf,
		      int flags);
extern int __fstatat64 (int dirfd, const char *pathname, struct stat64 *buf,
			int flags);
# if IS_IN (libc) || (IS_IN (rtld) && !defined NO_RTLD_HIDDEN)
hidden_proto (__stat64)
hidden_proto (__fstat64)
hidden_proto (__lstat64)
hidden_proto (__fstatat64)
# endif

# if __TIMESIZE == 64 || defined NO_RTLD_HIDDEN
#  define __stat64_time64  __stat64
#  define __fstat64_time64  __fstat64
#  define __lstat64_time64  __lstat64
#  define __fstatat64_time64  __fstatat64
# else
extern int __stat64_time64 (const char *file, struct __stat64_t64 *buf);
hidden_proto (__stat64_time64);
extern int __lstat64_time64 (const char *file, struct __stat64_t64 *buf);
hidden_proto (__lstat64_time64);
extern int __fstat64_time64 (int fd, struct __stat64_t64 *buf);
hidden_proto (__fstat64_time64);
extern int __fstatat64_time64 (int dirfd, const char *pathname,
			       struct __stat64_t64 *buf, int flags);
hidden_proto (__fstatat64_time64);
# endif

extern int __chmod (const char *__file, __mode_t __mode);
libc_hidden_proto (__chmod)
extern int __fchmod (int __fd, __mode_t __mode);
extern int __fchmodat (int __fd, const char *__file, mode_t __mode, int __flag);
libc_hidden_proto (fchmodat)
extern __mode_t __umask (__mode_t __mask);
extern int __mkdir (const char *__path, __mode_t __mode);
libc_hidden_proto (__mkdir)
extern int __mkdirat (int __fd, const char *__path, mode_t __mode);

extern int __mknodat (int fd, const char *path, mode_t mode, dev_t dev);
libc_hidden_proto (__mknodat);
extern int __mknod (const char *__path,
		    __mode_t __mode, __dev_t __dev);
libc_hidden_proto (__mknod);

extern int __xmknod (int __ver, const char *__path, __mode_t __mode,
		     __dev_t *__dev);
extern int __xmknodat (int __ver, int __fd, const char *__path,
		       __mode_t __mode, __dev_t *__dev);

int __fxstat (int __ver, int __fildes, struct stat *__stat_buf);
int __xstat (int __ver, const char *__filename,
	     struct stat *__stat_buf);
int __lxstat (int __ver, const char *__filename, struct stat *__stat_buf);
int __fxstatat (int __ver, int __fildes, const char *__filename,
		struct stat *__stat_buf, int __flag);
int __fxstat64 (int ver, int __fildes, struct stat64 *__stat_buf);
int __xstat64 (int ver, const char *__filename, struct stat64 *__stat_buf);
int __lxstat64 (int ver, const char *__filename, struct stat64 *__stat_buf);
int __fxstatat64 (int ver, int __fildes, const char *__filename,
		  struct stat64 *__stat_buf, int __flag);

#endif
#endif
