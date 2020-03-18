/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <stdio.h>
#include <io.h>
#include <errno.h>
#include <windows.h>
#include <internal.h>

struct oserr_map {
  unsigned long oscode; /* OS values */
  int errnocode; /* System V codes */
};

typedef union doubleint {
  __int64 bigint;
  struct {
    unsigned long lowerhalf;
    long upperhalf;
  } twoints;
} DINT;

#define _IOYOURBUF      0x0100
#define _IOSETVBUF      0x0400
#define _IOFEOF         0x0800
#define _IOFLRTN        0x1000
#define _IOCTRLZ        0x2000
#define _IOCOMMIT       0x4000

/* General use macros */

#define inuse(s)        ((s)->_flag & (_IOREAD|_IOWRT|_IORW))
#define mbuf(s)         ((s)->_flag & _IOMYBUF)
#define nbuf(s)         ((s)->_flag & _IONBF)
#define ybuf(s)         ((s)->_flag & _IOYOURBUF)
#define bigbuf(s)       ((s)->_flag & (_IOMYBUF|_IOYOURBUF))
#define anybuf(s)       ((s)->_flag & (_IOMYBUF|_IONBF|_IOYOURBUF))

#define _INTERNAL_BUFSIZ    4096
#define _SMALL_BUFSIZ       512

#define FOPEN           0x01    /* file handle open */
#define FEOFLAG         0x02    /* end of file has been encountered */
#define FCRLF           0x04    /* CR-LF across read buffer (in text mode) */
#define FPIPE           0x08    /* file handle refers to a pipe */
#define FNOINHERIT      0x10    /* file handle opened _O_NOINHERIT */
#define FAPPEND         0x20    /* file handle opened O_APPEND */
#define FDEV            0x40    /* file handle refers to device */
#define FTEXT           0x80    /* file handle is in text mode */

static struct oserr_map local_errtab[] = {
  { ERROR_INVALID_FUNCTION, EINVAL }, { ERROR_FILE_NOT_FOUND, ENOENT },
  { ERROR_PATH_NOT_FOUND, ENOENT }, { ERROR_TOO_MANY_OPEN_FILES, EMFILE },
  { ERROR_ACCESS_DENIED, EACCES }, { ERROR_INVALID_HANDLE, EBADF },
  { ERROR_ARENA_TRASHED, ENOMEM }, { ERROR_NOT_ENOUGH_MEMORY, ENOMEM },
  { ERROR_INVALID_BLOCK, ENOMEM }, { ERROR_BAD_ENVIRONMENT, E2BIG },
  { ERROR_BAD_FORMAT, ENOEXEC }, { ERROR_INVALID_ACCESS, EINVAL },
  { ERROR_INVALID_DATA, EINVAL }, { ERROR_INVALID_DRIVE, ENOENT },
  { ERROR_CURRENT_DIRECTORY, EACCES }, { ERROR_NOT_SAME_DEVICE, EXDEV },
  { ERROR_NO_MORE_FILES, ENOENT }, { ERROR_LOCK_VIOLATION, EACCES },
  { ERROR_BAD_NETPATH, ENOENT }, { ERROR_NETWORK_ACCESS_DENIED, EACCES },
  { ERROR_BAD_NET_NAME, ENOENT }, { ERROR_FILE_EXISTS, EEXIST },
  { ERROR_CANNOT_MAKE, EACCES }, { ERROR_FAIL_I24, EACCES },
  { ERROR_INVALID_PARAMETER, EINVAL }, { ERROR_NO_PROC_SLOTS, EAGAIN },
  { ERROR_DRIVE_LOCKED, EACCES }, { ERROR_BROKEN_PIPE, EPIPE },
  { ERROR_DISK_FULL, ENOSPC }, { ERROR_INVALID_TARGET_HANDLE, EBADF },
  { ERROR_INVALID_HANDLE, EINVAL }, { ERROR_WAIT_NO_CHILDREN, ECHILD },
  { ERROR_CHILD_NOT_COMPLETE, ECHILD }, { ERROR_DIRECT_ACCESS_HANDLE, EBADF },
  { ERROR_NEGATIVE_SEEK, EINVAL }, { ERROR_SEEK_ON_DEVICE, EACCES },
  { ERROR_DIR_NOT_EMPTY, ENOTEMPTY }, { ERROR_NOT_LOCKED, EACCES },
  { ERROR_BAD_PATHNAME, ENOENT }, { ERROR_MAX_THRDS_REACHED, EAGAIN },
  { ERROR_LOCK_FAILED, EACCES }, { ERROR_ALREADY_EXISTS, EEXIST },
  { ERROR_FILENAME_EXCED_RANGE, ENOENT }, { ERROR_NESTING_NOT_ALLOWED, EAGAIN },
  { ERROR_NOT_ENOUGH_QUOTA, ENOMEM }, { 0, -1 }
};

void mingw_dosmaperr (unsigned long oserrno);

int fseeko64 (FILE* stream, _off64_t offset, int whence)
{
  fpos_t pos;
  if (whence == SEEK_CUR)
    {
      /* If stream is invalid, fgetpos sets errno. */
      if (fgetpos (stream, &pos))
        return (-1);
      pos += (fpos_t) offset;
    }
  else if (whence == SEEK_END)
    {
      /* If writing, we need to flush before getting file length.  */
      fflush (stream);
      pos = (fpos_t) (_filelengthi64 (_fileno (stream)) + offset);
    }
  else if (whence == SEEK_SET)
    pos = (fpos_t) offset;
  else
    {
      errno = EINVAL;
      return (-1);
    }
  return fsetpos (stream, &pos);
}

void mingw_dosmaperr (unsigned long oserrno)
{
  size_t i;

  _doserrno = oserrno;        /* set _doserrno */
  /* check the table for the OS error code */
  i = 0;
  do {
    if (oserrno == local_errtab[i].oscode)
    {
      errno = local_errtab[i].errnocode;
      return;
    }
  } while (local_errtab[++i].errnocode != -1);
  if (oserrno >= ERROR_WRITE_PROTECT && oserrno <= ERROR_SHARING_BUFFER_EXCEEDED)
    errno = EACCES;
  else if (oserrno >= ERROR_INVALID_STARTING_CODESEG && oserrno <= ERROR_INFLOOP_IN_RELOC_CHAIN)
    errno = ENOEXEC;
  else
    errno = EINVAL;
}
