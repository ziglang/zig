/* Copyright (C) 1991-2024 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

/*
 *	POSIX Standard: 5.6 File Characteristics	<sys/stat.h>
 */

#ifndef	_SYS_STAT_H
#define	_SYS_STAT_H	1

#include <features.h>

#include <bits/types.h>		/* For __mode_t and __dev_t.  */

#ifdef __USE_XOPEN2K8
# include <bits/types/struct_timespec.h>
#endif

#if defined __USE_XOPEN || defined __USE_XOPEN2K
/* The Single Unix specification says that some more types are
   available here.  */

# include <bits/types/time_t.h>

# ifndef __dev_t_defined
typedef __dev_t dev_t;
#  define __dev_t_defined
# endif

# ifndef __gid_t_defined
typedef __gid_t gid_t;
#  define __gid_t_defined
# endif

# ifndef __ino_t_defined
#  ifndef __USE_FILE_OFFSET64
typedef __ino_t ino_t;
#  else
typedef __ino64_t ino_t;
#  endif
#  define __ino_t_defined
# endif

# ifndef __mode_t_defined
typedef __mode_t mode_t;
#  define __mode_t_defined
# endif

# ifndef __nlink_t_defined
typedef __nlink_t nlink_t;
#  define __nlink_t_defined
# endif

# ifndef __off_t_defined
#  ifndef __USE_FILE_OFFSET64
typedef __off_t off_t;
#  else
typedef __off64_t off_t;
#  endif
#  define __off_t_defined
# endif

# ifndef __uid_t_defined
typedef __uid_t uid_t;
#  define __uid_t_defined
# endif
#endif	/* X/Open */

#ifdef __USE_UNIX98
# ifndef __blkcnt_t_defined
#  ifndef __USE_FILE_OFFSET64
typedef __blkcnt_t blkcnt_t;
#  else
typedef __blkcnt64_t blkcnt_t;
#  endif
#  define __blkcnt_t_defined
# endif

# ifndef __blksize_t_defined
typedef __blksize_t blksize_t;
#  define __blksize_t_defined
# endif
#endif	/* Unix98 */

__BEGIN_DECLS

#include <bits/stat.h>

#if defined __USE_MISC || defined __USE_XOPEN
# define S_IFMT		__S_IFMT
# define S_IFDIR	__S_IFDIR
# define S_IFCHR	__S_IFCHR
# define S_IFBLK	__S_IFBLK
# define S_IFREG	__S_IFREG
# ifdef __S_IFIFO
#  define S_IFIFO	__S_IFIFO
# endif
# ifdef __S_IFLNK
#  define S_IFLNK	__S_IFLNK
# endif
# if (defined __USE_MISC || defined __USE_XOPEN_EXTENDED) \
     && defined __S_IFSOCK
#  define S_IFSOCK	__S_IFSOCK
# endif
#endif

/* Test macros for file types.	*/

#define	__S_ISTYPE(mode, mask)	(((mode) & __S_IFMT) == (mask))

#define	S_ISDIR(mode)	 __S_ISTYPE((mode), __S_IFDIR)
#define	S_ISCHR(mode)	 __S_ISTYPE((mode), __S_IFCHR)
#define	S_ISBLK(mode)	 __S_ISTYPE((mode), __S_IFBLK)
#define	S_ISREG(mode)	 __S_ISTYPE((mode), __S_IFREG)
#ifdef __S_IFIFO
# define S_ISFIFO(mode)	 __S_ISTYPE((mode), __S_IFIFO)
#endif
#ifdef __S_IFLNK
# define S_ISLNK(mode)	 __S_ISTYPE((mode), __S_IFLNK)
#endif

#if defined __USE_MISC && !defined __S_IFLNK
# define S_ISLNK(mode)  0
#endif

#if (defined __USE_XOPEN_EXTENDED || defined __USE_XOPEN2K) \
    && defined __S_IFSOCK
# define S_ISSOCK(mode) __S_ISTYPE((mode), __S_IFSOCK)
#elif defined __USE_XOPEN2K
# define S_ISSOCK(mode) 0
#endif

/* These are from POSIX.1b.  If the objects are not implemented using separate
   distinct file types, the macros always will evaluate to zero.  Unlike the
   other S_* macros the following three take a pointer to a `struct stat'
   object as the argument.  */
#ifdef	__USE_POSIX199309
# define S_TYPEISMQ(buf) __S_TYPEISMQ(buf)
# define S_TYPEISSEM(buf) __S_TYPEISSEM(buf)
# define S_TYPEISSHM(buf) __S_TYPEISSHM(buf)
#endif


/* Protection bits.  */

#define	S_ISUID __S_ISUID	/* Set user ID on execution.  */
#define	S_ISGID	__S_ISGID	/* Set group ID on execution.  */

#if defined __USE_MISC || defined __USE_XOPEN
/* Save swapped text after use (sticky bit).  This is pretty well obsolete.  */
# define S_ISVTX	__S_ISVTX
#endif

#define	S_IRUSR	__S_IREAD	/* Read by owner.  */
#define	S_IWUSR	__S_IWRITE	/* Write by owner.  */
#define	S_IXUSR	__S_IEXEC	/* Execute by owner.  */
/* Read, write, and execute by owner.  */
#define	S_IRWXU	(__S_IREAD|__S_IWRITE|__S_IEXEC)

#ifdef __USE_MISC
# define S_IREAD	S_IRUSR
# define S_IWRITE	S_IWUSR
# define S_IEXEC	S_IXUSR
#endif

#define	S_IRGRP	(S_IRUSR >> 3)	/* Read by group.  */
#define	S_IWGRP	(S_IWUSR >> 3)	/* Write by group.  */
#define	S_IXGRP	(S_IXUSR >> 3)	/* Execute by group.  */
/* Read, write, and execute by group.  */
#define	S_IRWXG	(S_IRWXU >> 3)

#define	S_IROTH	(S_IRGRP >> 3)	/* Read by others.  */
#define	S_IWOTH	(S_IWGRP >> 3)	/* Write by others.  */
#define	S_IXOTH	(S_IXGRP >> 3)	/* Execute by others.  */
/* Read, write, and execute by others.  */
#define	S_IRWXO	(S_IRWXG >> 3)


#ifdef	__USE_MISC
/* Macros for common mode bit masks.  */
# define ACCESSPERMS (S_IRWXU|S_IRWXG|S_IRWXO) /* 0777 */
# define ALLPERMS (S_ISUID|S_ISGID|S_ISVTX|S_IRWXU|S_IRWXG|S_IRWXO)/* 07777 */
# define DEFFILEMODE (S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH)/* 0666*/

# define S_BLKSIZE	512	/* Block size for `st_blocks'.  */
#endif


#ifndef __USE_FILE_OFFSET64
/* Get file attributes for FILE and put them in BUF.  */
extern int stat (const char *__restrict __file,
		 struct stat *__restrict __buf) __THROW __nonnull ((1, 2));

/* Get file attributes for the file, device, pipe, or socket
   that file descriptor FD is open on and put them in BUF.  */
extern int fstat (int __fd, struct stat *__buf) __THROW __nonnull ((2));
#else
# ifdef __USE_TIME64_REDIRECTS
#  ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (stat, (const char *__restrict __file,
				  struct stat *__restrict __buf),
				  __stat64_time64)
     __nonnull ((1, 2));
extern int __REDIRECT_NTH (fstat, (int __fd, struct stat *__buf),
				   __fstat64_time64)
     __nonnull ((2));
#  else
#   define stat __stat64_time64
#   define fstat __fstat64_time64
#  endif
# else
#  ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (stat, (const char *__restrict __file,
				  struct stat *__restrict __buf), stat64)
     __nonnull ((1, 2));
extern int __REDIRECT_NTH (fstat, (int __fd, struct stat *__buf), fstat64)
     __nonnull ((2));
#  else
#   define stat stat64
#   define fstat fstat64
#  endif
# endif
#endif
#ifdef __USE_LARGEFILE64
# ifndef __USE_TIME64_REDIRECTS
extern int stat64 (const char *__restrict __file,
		   struct stat64 *__restrict __buf) __THROW __nonnull ((1, 2));
extern int fstat64 (int __fd, struct stat64 *__buf) __THROW __nonnull ((2));
# else
#  ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (stat64, (const char *__restrict __file,
				    struct stat64 *__restrict __buf),
			   __stat64_time64)
     __nonnull ((1, 2));
extern int __REDIRECT_NTH (fstat64, (int __fd, struct stat64 *__buf),
			   __fstat64_time64)
     __nonnull ((2));
#  else
#   define stat64 __stat64_time64
#   define fstat64 __fstat64_time64
#  endif
# endif
#endif

#ifdef __USE_ATFILE
/* Similar to stat, get the attributes for FILE and put them in BUF.
   Relative path names are interpreted relative to FD unless FD is
   AT_FDCWD.  */
# ifndef __USE_FILE_OFFSET64
extern int fstatat (int __fd, const char *__restrict __file,
		    struct stat *__restrict __buf, int __flag)
     __THROW __nonnull ((2, 3));
# else
#  ifdef __USE_TIME64_REDIRECTS
#   ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (fstatat, (int __fd, const char *__restrict __file,
				     struct stat *__restrict __buf,
				     int __flag),
			   __fstatat64_time64) __nonnull ((2, 3));
#   else
#    define fstatat __fstatat64_time64
#   endif
#  else
#   ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (fstatat, (int __fd, const char *__restrict __file,
				     struct stat *__restrict __buf,
				     int __flag),
			   fstatat64) __nonnull ((2, 3));
#   else
#    define fstatat fstatat64
#   endif
#  endif
# endif

# ifdef __USE_LARGEFILE64
#  ifndef __USE_TIME64_REDIRECTS
extern int fstatat64 (int __fd, const char *__restrict __file,
		      struct stat64 *__restrict __buf, int __flag)
     __THROW __nonnull ((2, 3));
#  else
#   ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (fstatat64, (int __fd,
				       const char *__restrict __file,
				       struct stat64 *__restrict __buf,
				       int __flag),
			   __fstatat64_time64)
     __nonnull ((2, 3));
#   else
#    define fstatat64 __fstatat64_time64
#   endif
#  endif
# endif
#endif

#if defined __USE_XOPEN_EXTENDED || defined __USE_XOPEN2K
# ifndef __USE_FILE_OFFSET64
/* Get file attributes about FILE and put them in BUF.
   If FILE is a symbolic link, do not follow it.  */
extern int lstat (const char *__restrict __file,
		  struct stat *__restrict __buf) __THROW __nonnull ((1, 2));
# else
#  ifdef __USE_TIME64_REDIRECTS
#   ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (lstat,
			   (const char *__restrict __file,
			    struct stat *__restrict __buf), __lstat64_time64)
     __nonnull ((1, 2));
#   else
#    define lstat __lstat64_time64
#   endif
#  else
#   ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (lstat,
			   (const char *__restrict __file,
			    struct stat *__restrict __buf), lstat64)
     __nonnull ((1, 2));
#   else
#    define lstat lstat64
#   endif
#  endif
# endif
# ifdef __USE_LARGEFILE64
#  ifndef __USE_TIME64_REDIRECTS
extern int lstat64 (const char *__restrict __file,
		    struct stat64 *__restrict __buf)
     __THROW __nonnull ((1, 2));
#  else
extern int __REDIRECT_NTH (lstat64, (const char *__restrict __file,
				     struct stat64 *__restrict __buf),
			   __lstat64_time64)
     __nonnull ((1, 2));
#  endif
# endif
#endif

/* Set file access permissions for FILE to MODE.
   If FILE is a symbolic link, this affects its target instead.  */
extern int chmod (const char *__file, __mode_t __mode)
     __THROW __nonnull ((1));

#ifdef __USE_MISC
/* Set file access permissions for FILE to MODE.
   If FILE is a symbolic link, this affects the link itself
   rather than its target.  */
extern int lchmod (const char *__file, __mode_t __mode)
     __THROW __nonnull ((1));
#endif

/* Set file access permissions of the file FD is open on to MODE.  */
#if defined __USE_POSIX199309 || defined __USE_XOPEN_EXTENDED
extern int fchmod (int __fd, __mode_t __mode) __THROW;
#endif

#ifdef __USE_ATFILE
/* Set file access permissions of FILE relative to
   the directory FD is open on.  */
extern int fchmodat (int __fd, const char *__file, __mode_t __mode,
		     int __flag)
     __THROW __nonnull ((2)) __wur;
#endif /* Use ATFILE.  */



/* Set the file creation mask of the current process to MASK,
   and return the old creation mask.  */
extern __mode_t umask (__mode_t __mask) __THROW;

#ifdef	__USE_GNU
/* Get the current `umask' value without changing it.
   This function is only available under the GNU Hurd.  */
extern __mode_t getumask (void) __THROW;
#endif

/* Create a new directory named PATH, with permission bits MODE.  */
extern int mkdir (const char *__path, __mode_t __mode)
     __THROW __nonnull ((1));

#ifdef __USE_ATFILE
/* Like mkdir, create a new directory with permission bits MODE.  But
   interpret relative PATH names relative to the directory associated
   with FD.  */
extern int mkdirat (int __fd, const char *__path, __mode_t __mode)
     __THROW __nonnull ((2));
#endif

/* Create a device file named PATH, with permission and special bits MODE
   and device number DEV (which can be constructed from major and minor
   device numbers with the `makedev' macro above).  */
#if defined __USE_MISC || defined __USE_XOPEN_EXTENDED
extern int mknod (const char *__path, __mode_t __mode, __dev_t __dev)
     __THROW __nonnull ((1));

# ifdef __USE_ATFILE
/* Like mknod, create a new device file with permission bits MODE and
   device number DEV.  But interpret relative PATH names relative to
   the directory associated with FD.  */
extern int mknodat (int __fd, const char *__path, __mode_t __mode,
		    __dev_t __dev) __THROW __nonnull ((2));
# endif
#endif


/* Create a new FIFO named PATH, with permission bits MODE.  */
extern int mkfifo (const char *__path, __mode_t __mode)
     __THROW __nonnull ((1));

#ifdef __USE_ATFILE
/* Like mkfifo, create a new FIFO with permission bits MODE.  But
   interpret relative PATH names relative to the directory associated
   with FD.  */
extern int mkfifoat (int __fd, const char *__path, __mode_t __mode)
     __THROW __nonnull ((2));
#endif

#ifdef __USE_ATFILE
# ifndef __USE_TIME64_REDIRECTS
/* Set file access and modification times relative to directory file
   descriptor.  */
extern int utimensat (int __fd, const char *__path,
		      const struct timespec __times[2],
		      int __flags)
     __THROW __nonnull ((2));
# else
#  ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (utimensat, (int fd, const char *__path,
                                       const struct timespec __times[2],
                                       int flags),
                           __utimensat64) __nonnull ((2));
#  else
#   define utimensat __utimensat64
#  endif
# endif
#endif

#ifdef __USE_XOPEN2K8
# ifndef __USE_TIME64_REDIRECTS
/* Set file access and modification times of the file associated with FD.  */
extern int futimens (int __fd, const struct timespec __times[2]) __THROW;

# else
#  ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (futimens, (int fd, const struct timespec __times[2]),
                           __futimens64);
#  else
#   define futimens __futimens64
#  endif
# endif
#endif

#ifdef __USE_GNU
# include <bits/statx.h>
#endif

__END_DECLS


#endif /* sys/stat.h  */