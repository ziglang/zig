/* Header file for mounting/unmount Linux filesystems.
   Copyright (C) 1996-2024 Free Software Foundation, Inc.
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

/* This is taken from /usr/include/linux/fs.h.  */

#ifndef _SYS_MOUNT_H
#define _SYS_MOUNT_H	1

#include <fcntl.h>
#include <features.h>
#include <stdint.h>
#include <stddef.h>
#include <sys/ioctl.h>

#ifdef __has_include
# if __has_include ("linux/mount.h")
#  include "linux/mount.h"
# endif
#endif


#define BLOCK_SIZE_BITS	10
#define BLOCK_SIZE	(1<<BLOCK_SIZE_BITS)


/* These are the fs-independent mount-flags: up to 16 flags are
   supported  */
enum
{
#undef MS_RDONLY
  MS_RDONLY = 1,		/* Mount read-only.  */
#define MS_RDONLY	MS_RDONLY
#undef MS_NOSUID
  MS_NOSUID = 2,		/* Ignore suid and sgid bits.  */
#define MS_NOSUID	MS_NOSUID
#undef MS_NODEV
  MS_NODEV = 4,			/* Disallow access to device special files.  */
#define MS_NODEV	MS_NODEV
#undef MS_NOEXEC
  MS_NOEXEC = 8,		/* Disallow program execution.  */
#define MS_NOEXEC	MS_NOEXEC
#undef MS_SYNCHRONOUS
  MS_SYNCHRONOUS = 16,		/* Writes are synced at once.  */
#define MS_SYNCHRONOUS	MS_SYNCHRONOUS
#undef MS_REMOUNT
  MS_REMOUNT = 32,		/* Alter flags of a mounted FS.  */
#define MS_REMOUNT	MS_REMOUNT
#undef MS_MANDLOCK
  MS_MANDLOCK = 64,		/* Allow mandatory locks on an FS.  */
#define MS_MANDLOCK	MS_MANDLOCK
#undef MS_DIRSYNC
  MS_DIRSYNC = 128,		/* Directory modifications are synchronous.  */
#define MS_DIRSYNC	MS_DIRSYNC
#undef MS_NOSYMFOLLOW
  MS_NOSYMFOLLOW = 256,		/* Do not follow symlinks.  */
#define MS_NOSYMFOLLOW	MS_NOSYMFOLLOW
#undef MS_NOATIME
  MS_NOATIME = 1024,		/* Do not update access times.  */
#define MS_NOATIME	MS_NOATIME
#undef MS_NODIRATIME
  MS_NODIRATIME = 2048,		/* Do not update directory access times.  */
#define MS_NODIRATIME	MS_NODIRATIME
#undef MS_BIND
  MS_BIND = 4096,		/* Bind directory at different place.  */
#define MS_BIND		MS_BIND
#undef MS_MOVE
  MS_MOVE = 8192,
#define MS_MOVE		MS_MOVE
#undef MS_REC
  MS_REC = 16384,
#define MS_REC		MS_REC
#undef MS_SILENT
  MS_SILENT = 32768,
#define MS_SILENT	MS_SILENT
#undef MS_POSIXACL
  MS_POSIXACL = 1 << 16,	/* VFS does not apply the umask.  */
#define MS_POSIXACL	MS_POSIXACL
#undef MS_UNBINDABLE
  MS_UNBINDABLE = 1 << 17,	/* Change to unbindable.  */
#define MS_UNBINDABLE	MS_UNBINDABLE
#undef MS_PRIVATE
  MS_PRIVATE = 1 << 18,		/* Change to private.  */
#define MS_PRIVATE	MS_PRIVATE
#undef MS_SLAVE
  MS_SLAVE = 1 << 19,		/* Change to slave.  */
#define MS_SLAVE	MS_SLAVE
#undef MS_SHARED
  MS_SHARED = 1 << 20,		/* Change to shared.  */
#define MS_SHARED	MS_SHARED
#undef MS_RELATIME
  MS_RELATIME = 1 << 21,	/* Update atime relative to mtime/ctime.  */
#define MS_RELATIME	MS_RELATIME
#undef MS_KERNMOUNT
  MS_KERNMOUNT = 1 << 22,	/* This is a kern_mount call.  */
#define MS_KERNMOUNT	MS_KERNMOUNT
#undef MS_I_VERSION
  MS_I_VERSION =  1 << 23,	/* Update inode I_version field.  */
#define MS_I_VERSION	MS_I_VERSION
#undef MS_STRICTATIME
  MS_STRICTATIME = 1 << 24,	/* Always perform atime updates.  */
#define MS_STRICTATIME	MS_STRICTATIME
#undef MS_LAZYTIME
  MS_LAZYTIME = 1 << 25,	/* Update the on-disk [acm]times lazily.  */
#define MS_LAZYTIME	MS_LAZYTIME
#undef MS_ACTIVE
  MS_ACTIVE = 1 << 30,
#define MS_ACTIVE	MS_ACTIVE
#undef MS_NOUSER
  MS_NOUSER = 1 << 31
#define MS_NOUSER	MS_NOUSER
};

/* Flags that can be altered by MS_REMOUNT  */
#undef MS_RMT_MASK
#define MS_RMT_MASK (MS_RDONLY|MS_SYNCHRONOUS|MS_MANDLOCK|MS_I_VERSION \
		     |MS_LAZYTIME)


/* Magic mount flag number. Has to be or-ed to the flag values.  */

#undef MS_MGC_VAL
#define MS_MGC_VAL 0xc0ed0000	/* Magic flag number to indicate "new" flags */
#define MS_MGC_MSK 0xffff0000	/* Magic flag number mask */


/* The read-only stuff doesn't really belong here, but any other place
   is probably as bad and I don't want to create yet another include
   file.  */

#undef BLKROSET
#define BLKROSET   _IO(0x12, 93) /* Set device read-only (0 = read-write).  */
#undef BLKROGET
#define BLKROGET   _IO(0x12, 94) /* Get read-only status (0 = read_write).  */
#undef BLKRRPART
#define BLKRRPART  _IO(0x12, 95) /* Re-read partition table.  */
#undef BLKGETSIZE
#define BLKGETSIZE _IO(0x12, 96) /* Return device size.  */
#undef BLKFLSBUF
#define BLKFLSBUF  _IO(0x12, 97) /* Flush buffer cache.  */
#undef BLKRASET
#define BLKRASET   _IO(0x12, 98) /* Set read ahead for block device.  */
#undef BLKRAGET
#define BLKRAGET   _IO(0x12, 99) /* Get current read ahead setting.  */
#undef BLKFRASET
#define BLKFRASET  _IO(0x12,100) /* Set filesystem read-ahead.  */
#undef BLKFRAGET
#define BLKFRAGET  _IO(0x12,101) /* Get filesystem read-ahead.  */
#undef BLKSECTSET
#define BLKSECTSET _IO(0x12,102) /* Set max sectors per request.  */
#undef BLKSECTGET
#define BLKSECTGET _IO(0x12,103) /* Get max sectors per request.  */
#undef BLKSSZGET
#define BLKSSZGET  _IO(0x12,104) /* Get block device sector size.  */
#undef BLKBSZGET
#define BLKBSZGET  _IOR(0x12,112,size_t)
#undef BLKBSZSET
#define BLKBSZSET  _IOW(0x12,113,size_t)
#undef BLKGETSIZE64
#define BLKGETSIZE64 _IOR(0x12,114,size_t) /* return device size.  */


/* Possible value for FLAGS parameter of `umount2'.  */
enum
{
  MNT_FORCE = 1,		/* Force unmounting.  */
#define MNT_FORCE MNT_FORCE
  MNT_DETACH = 2,		/* Just detach from the tree.  */
#define MNT_DETACH MNT_DETACH
  MNT_EXPIRE = 4,		/* Mark for expiry.  */
#define MNT_EXPIRE MNT_EXPIRE
  UMOUNT_NOFOLLOW = 8		/* Don't follow symlink on umount.  */
#define UMOUNT_NOFOLLOW UMOUNT_NOFOLLOW
};


/* fsmount flags.  */
#define FSMOUNT_CLOEXEC         0x00000001

/* mount attributes used on fsmount.  */
#define MOUNT_ATTR_RDONLY       0x00000001 /* Mount read-only.  */
#define MOUNT_ATTR_NOSUID       0x00000002 /* Ignore suid and sgid bits.  */
#define MOUNT_ATTR_NODEV        0x00000004 /* Disallow access to device special files.  */
#define MOUNT_ATTR_NOEXEC       0x00000008 /* Disallow program execution.  */
#define MOUNT_ATTR__ATIME       0x00000070 /* Setting on how atime should be updated.  */
#define MOUNT_ATTR_RELATIME     0x00000000 /* - Update atime relative to mtime/ctime.  */
#define MOUNT_ATTR_NOATIME      0x00000010 /* - Do not update access times.  */
#define MOUNT_ATTR_STRICTATIME  0x00000020 /* - Always perform atime updates  */
#define MOUNT_ATTR_NODIRATIME   0x00000080 /* Do not update directory access times.  */
#define MOUNT_ATTR_IDMAP        0x00100000 /* Idmap mount to @userns_fd in struct mount_attr.  */
#define MOUNT_ATTR_NOSYMFOLLOW  0x00200000 /* Do not follow symlinks.  */


#ifndef MOUNT_ATTR_SIZE_VER0
/* For mount_setattr.  */
struct mount_attr
{
  uint64_t attr_set;
  uint64_t attr_clr;
  uint64_t propagation;
  uint64_t userns_fd;
};
#endif

#define MOUNT_ATTR_SIZE_VER0    32 /* sizeof first published struct */

/* move_mount flags.  */
#define MOVE_MOUNT_F_SYMLINKS   0x00000001 /* Follow symlinks on from path */
#define MOVE_MOUNT_F_AUTOMOUNTS 0x00000002 /* Follow automounts on from path */
#define MOVE_MOUNT_F_EMPTY_PATH 0x00000004 /* Empty from path permitted */
#define MOVE_MOUNT_T_SYMLINKS   0x00000010 /* Follow symlinks on to path */
#define MOVE_MOUNT_T_AUTOMOUNTS 0x00000020 /* Follow automounts on to path */
#define MOVE_MOUNT_T_EMPTY_PATH 0x00000040 /* Empty to path permitted */
#define MOVE_MOUNT_SET_GROUP    0x00000100 /* Set sharing group instead */
#define MOVE_MOUNT_BENEATH      0x00000200 /* Mount beneath top mount */


/* fspick flags.  */
#define FSPICK_CLOEXEC          0x00000001
#define FSPICK_SYMLINK_NOFOLLOW 0x00000002
#define FSPICK_NO_AUTOMOUNT     0x00000004
#define FSPICK_EMPTY_PATH       0x00000008


#ifndef FSOPEN_CLOEXEC
/* The type of fsconfig call made.   */
enum fsconfig_command
{
  FSCONFIG_SET_FLAG       = 0,    /* Set parameter, supplying no value */
# define FSCONFIG_SET_FLAG FSCONFIG_SET_FLAG
  FSCONFIG_SET_STRING     = 1,    /* Set parameter, supplying a string value */
# define FSCONFIG_SET_STRING FSCONFIG_SET_STRING
  FSCONFIG_SET_BINARY     = 2,    /* Set parameter, supplying a binary blob value */
# define FSCONFIG_SET_BINARY FSCONFIG_SET_BINARY
  FSCONFIG_SET_PATH       = 3,    /* Set parameter, supplying an object by path */
# define FSCONFIG_SET_PATH FSCONFIG_SET_PATH
  FSCONFIG_SET_PATH_EMPTY = 4,    /* Set parameter, supplying an object by (empty) path */
# define FSCONFIG_SET_PATH_EMPTY FSCONFIG_SET_PATH_EMPTY
  FSCONFIG_SET_FD         = 5,    /* Set parameter, supplying an object by fd */
# define FSCONFIG_SET_FD FSCONFIG_SET_FD
  FSCONFIG_CMD_CREATE     = 6,    /* Invoke superblock creation */
# define FSCONFIG_CMD_CREATE FSCONFIG_CMD_CREATE
  FSCONFIG_CMD_RECONFIGURE = 7,   /* Invoke superblock reconfiguration */
# define FSCONFIG_CMD_RECONFIGURE FSCONFIG_CMD_RECONFIGURE
  FSCONFIG_CMD_CREATE_EXCL = 8,    /* Create new superblock, fail if reusing existing superblock */
# define FSCONFIG_CMD_CREATE_EXCL FSCONFIG_CMD_CREATE_EXCL
};
#endif

/* fsopen flags.  */
#define FSOPEN_CLOEXEC          0x00000001

/* open_tree flags.  */
#define OPEN_TREE_CLONE    1         /* Clone the target tree and attach the clone */
#define OPEN_TREE_CLOEXEC  O_CLOEXEC /* Close the file on execve() */


__BEGIN_DECLS

/* Mount a filesystem.  */
extern int mount (const char *__special_file, const char *__dir,
		  const char *__fstype, unsigned long int __rwflag,
		  const void *__data) __THROW;

/* Unmount a filesystem.  */
extern int umount (const char *__special_file) __THROW;

/* Unmount a filesystem.  Force unmounting if FLAGS is set to MNT_FORCE.  */
extern int umount2 (const char *__special_file, int __flags) __THROW;

/* Open the filesystem referenced by FS_NAME so it can be configured for
   mouting.  */
extern int fsopen (const char *__fs_name, unsigned int __flags) __THROW;

/* Create a mount representation for the FD created by fsopen using
   FLAGS with ATTR_FLAGS describing how the mount is to be performed.  */
extern int fsmount (int __fd, unsigned int __flags,
		    unsigned int __ms_flags) __THROW;

/* Add the mounted FROM_DFD referenced by FROM_PATHNAME filesystem returned
   by fsmount in the hierarchy in the place TO_DFD reference by TO_PATHNAME
   using FLAGS.  */
extern int move_mount (int __from_dfd, const char *__from_pathname,
		       int __to_dfd, const char *__to_pathname,
		       unsigned int flags) __THROW;

/* Set parameters and trigger CMD action on the FD context.  KEY, VALUE,
   and AUX are used depending ng of the CMD.  */
extern int fsconfig (int __fd, unsigned int __cmd, const char *__key,
		     const void *__value, int __aux) __THROW;

/* Equivalent of fopen for an existing mount point.  */
extern int fspick (int __dfd, const char *__path, unsigned int __flags)
  __THROW;

/* Open the mount point FILENAME in directory DFD using FLAGS.  */
extern int open_tree (int __dfd, const char *__filename, unsigned int __flags)
  __THROW;

/* Change the mount properties of the mount or an entire mount tree.  If
   PATH is a relative pathname, then it is interpreted relative to the
   directory referred to by the file descriptor dirfd.  Otherwise if DFD is
   the special value AT_FDCWD then PATH is interpreted relative to the current
   working directory of the calling process.  */
extern int mount_setattr (int __dfd, const char *__path, unsigned int __flags,
			  struct mount_attr *__uattr, size_t __usize)
  __THROW;

__END_DECLS

#endif /* _SYS_MOUNT_H */