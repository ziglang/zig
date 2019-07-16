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

_CRTIMP __int64 __cdecl _lseeki64(int fh,__int64 pos,int mthd);
__int64 __cdecl _ftelli64(FILE *str);
void mingw_dosmaperr (unsigned long oserrno);
int __cdecl _flush (FILE *str);

int __cdecl _flush (FILE *str)
{
  FILE *stream;
  int rc = 0; /* assume good return */
  __int64 nchar;

  stream = str;
  if ((stream->_flag & (_IOREAD | _IOWRT)) == _IOWRT && bigbuf(stream)
      && (nchar = (__int64) (stream->_ptr - stream->_base)) > 0ll)
  {
    if ( _write(_fileno(stream), stream->_base, nchar) == nchar) {
      if (_IORW & stream->_flag)
        stream->_flag &= ~_IOWRT;
    } else {
      stream->_flag |= _IOERR;
      rc = EOF;
    }
  }
  stream->_ptr = stream->_base;
  stream->_cnt = 0ll;
  return rc;
}

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

int __cdecl _fseeki64(FILE *str,__int64 offset,int whence)
{
        FILE *stream;
        /* Init stream pointer */
        stream = str;
        errno=0;
        if(!stream || ((whence != SEEK_SET) && (whence != SEEK_CUR) && (whence != SEEK_END)))
	{
	  errno=EINVAL;
	  return -1;
        }
        /* Clear EOF flag */
        stream->_flag &= ~_IOEOF;

        if (whence == SEEK_CUR) {
	  offset += _ftelli64(stream);
	  whence = SEEK_SET;
	}
        /* Flush buffer as necessary */
        _flush(stream);

        /* If file opened for read/write, clear flags since we don't know
           what the user is going to do next. If the file was opened for
           read access only, decrease _bufsiz so that the next _filbuf
           won't cost quite so much */

        if (stream->_flag & _IORW)
                stream->_flag &= ~(_IOWRT|_IOREAD);
        else if ( (stream->_flag & _IOREAD) && (stream->_flag & _IOMYBUF) &&
                  !(stream->_flag & _IOSETVBUF) )
                stream->_bufsiz = _SMALL_BUFSIZ;

        /* Seek to the desired locale and return. */

        return (_lseeki64(_fileno(stream), offset, whence) == -1ll ? -1 : 0);
}

__int64 __cdecl _ftelli64(FILE *str)
{
        FILE *stream;
        size_t offset;
        __int64 filepos;
        register char *p;
        char *max;
        int fd;
        size_t rdcnt = 0;

	errno=0;
        stream = str;
        fd = _fileno(stream);
        if (stream->_cnt < 0ll) stream->_cnt = 0ll;
    if ((filepos = _lseeki64(fd, 0ll, SEEK_CUR)) < 0L)
      return -1ll;

    if (!bigbuf(stream))            /* _IONBF or no buffering designated */
      return (filepos - (__int64) stream->_cnt);

    offset = (size_t)(stream->_ptr - stream->_base);

    if (stream->_flag & (_IOWRT|_IOREAD))
      {
        if (_osfile(fd) & FTEXT)
          for (p = stream->_base; p < stream->_ptr; p++)
            if (*p == '\n')  /* adjust for '\r' */
              offset++;
      }
      else if (!(stream->_flag & _IORW)) {
        errno=EINVAL;
        return -1ll;
      }
      if (filepos == 0ll)
        return ((__int64)offset);

      if (stream->_flag & _IOREAD)    /* go to preceding sector */
        {
          if (stream->_cnt == 0ll)  /* filepos holds correct location */
            offset = 0ll;
          else
            {
	          rdcnt = ((size_t) stream->_cnt) + ((size_t) (size_t)(stream->_ptr - stream->_base));
		      if (_osfile(fd) & FTEXT) {
		        if (_lseeki64(fd, 0ll, SEEK_END) == filepos) {
			      max = stream->_base + rdcnt;
			    for (p = stream->_base; p < max; p++)
			      if (*p == '\n') /* adjust for '\r' */
			        rdcnt++;
			    if (stream->_flag & _IOCTRLZ)
			      ++rdcnt;
		      } else {
		        _lseeki64(fd, filepos, SEEK_SET);
		        if ( (rdcnt <= _SMALL_BUFSIZ) && (stream->_flag & _IOMYBUF) &&
		            !(stream->_flag & _IOSETVBUF))
			      rdcnt = _SMALL_BUFSIZ;
		        else
		          rdcnt = stream->_bufsiz;
		        if  (_osfile(fd) & FCRLF)
		          ++rdcnt;
		      }
		    } /* end if FTEXT */
	    }
	  filepos -= (__int64)rdcnt;
    } /* end else stream->_cnt != 0 */
  return (filepos + (__int64)offset);
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
