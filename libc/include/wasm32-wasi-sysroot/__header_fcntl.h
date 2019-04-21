#ifndef __wasilibc___header_fcntl_h
#define __wasilibc___header_fcntl_h

#include <wasi/core.h>

#define O_APPEND __WASI_FDFLAG_APPEND
#define O_DSYNC __WASI_FDFLAG_DSYNC
#define O_NONBLOCK __WASI_FDFLAG_NONBLOCK
#define O_RSYNC __WASI_FDFLAG_RSYNC
#define O_SYNC __WASI_FDFLAG_SYNC
#define O_CREAT (__WASI_O_CREAT << 12)
#define O_DIRECTORY (__WASI_O_DIRECTORY << 12)
#define O_EXCL (__WASI_O_EXCL << 12)
#define O_TRUNC (__WASI_O_TRUNC << 12)

#define O_NOFOLLOW (0x01000000)
#define O_EXEC     (0x02000000)
#define O_RDONLY   (0x04000000)
#define O_SEARCH   (0x08000000)
#define O_WRONLY   (0x10000000)

#define O_CLOEXEC  (0)
#define O_NOCTTY   (0)

#define O_RDWR (O_RDONLY | O_WRONLY)
#define O_ACCMODE (O_EXEC | O_RDWR | O_SEARCH)

#define POSIX_FADV_DONTNEED __WASI_ADVICE_DONTNEED
#define POSIX_FADV_NOREUSE __WASI_ADVICE_NOREUSE
#define POSIX_FADV_NORMAL __WASI_ADVICE_NORMAL
#define POSIX_FADV_RANDOM __WASI_ADVICE_RANDOM
#define POSIX_FADV_SEQUENTIAL __WASI_ADVICE_SEQUENTIAL
#define POSIX_FADV_WILLNEED __WASI_ADVICE_WILLNEED

#define F_GETFD (1)
#define F_SETFD (2)
#define F_GETFL (3)
#define F_SETFL (4)

#define FD_CLOEXEC (1)

#define AT_EACCESS          (0x0)
#define AT_SYMLINK_NOFOLLOW (0x1)
#define AT_SYMLINK_FOLLOW   (0x2)
#define AT_REMOVEDIR        (0x4)

#endif
