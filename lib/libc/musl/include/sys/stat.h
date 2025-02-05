#ifndef	_SYS_STAT_H
#define	_SYS_STAT_H
#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>

#define __NEED_dev_t
#define __NEED_ino_t
#define __NEED_mode_t
#define __NEED_nlink_t
#define __NEED_uid_t
#define __NEED_gid_t
#define __NEED_off_t
#define __NEED_time_t
#define __NEED_blksize_t
#define __NEED_blkcnt_t
#define __NEED_struct_timespec

#ifdef _GNU_SOURCE
#define __NEED_int64_t
#define __NEED_uint64_t
#define __NEED_uint32_t
#define __NEED_uint16_t
#endif

#include <bits/alltypes.h>

#include <bits/stat.h>

#define st_atime st_atim.tv_sec
#define st_mtime st_mtim.tv_sec
#define st_ctime st_ctim.tv_sec

#define S_IFMT  0170000

#define S_IFDIR 0040000
#define S_IFCHR 0020000
#define S_IFBLK 0060000
#define S_IFREG 0100000
#define S_IFIFO 0010000
#define S_IFLNK 0120000
#define S_IFSOCK 0140000

#define S_TYPEISMQ(buf)  0
#define S_TYPEISSEM(buf) 0
#define S_TYPEISSHM(buf) 0
#define S_TYPEISTMO(buf) 0

#define S_ISDIR(mode)  (((mode) & S_IFMT) == S_IFDIR)
#define S_ISCHR(mode)  (((mode) & S_IFMT) == S_IFCHR)
#define S_ISBLK(mode)  (((mode) & S_IFMT) == S_IFBLK)
#define S_ISREG(mode)  (((mode) & S_IFMT) == S_IFREG)
#define S_ISFIFO(mode) (((mode) & S_IFMT) == S_IFIFO)
#define S_ISLNK(mode)  (((mode) & S_IFMT) == S_IFLNK)
#define S_ISSOCK(mode) (((mode) & S_IFMT) == S_IFSOCK)

#ifndef S_IRUSR
#define S_ISUID 04000
#define S_ISGID 02000
#define S_ISVTX 01000
#define S_IRUSR 0400
#define S_IWUSR 0200
#define S_IXUSR 0100
#define S_IRWXU 0700
#define S_IRGRP 0040
#define S_IWGRP 0020
#define S_IXGRP 0010
#define S_IRWXG 0070
#define S_IROTH 0004
#define S_IWOTH 0002
#define S_IXOTH 0001
#define S_IRWXO 0007
#endif

#define UTIME_NOW  0x3fffffff
#define UTIME_OMIT 0x3ffffffe

int stat(const char *__restrict, struct stat *__restrict);
int fstat(int, struct stat *);
int lstat(const char *__restrict, struct stat *__restrict);
int fstatat(int, const char *__restrict, struct stat *__restrict, int);
int chmod(const char *, mode_t);
int fchmod(int, mode_t);
int fchmodat(int, const char *, mode_t, int);
mode_t umask(mode_t);
int mkdir(const char *, mode_t);
int mkfifo(const char *, mode_t);
int mkdirat(int, const char *, mode_t);
int mkfifoat(int, const char *, mode_t);

#if defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
int mknod(const char *, mode_t, dev_t);
int mknodat(int, const char *, mode_t, dev_t);
#endif

int futimens(int, const struct timespec [2]);
int utimensat(int, const char *, const struct timespec [2], int);

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
int lchmod(const char *, mode_t);
#define S_IREAD S_IRUSR
#define S_IWRITE S_IWUSR
#define S_IEXEC S_IXUSR
#endif

#if defined(_GNU_SOURCE)
#define STATX_TYPE 1U
#define STATX_MODE 2U
#define STATX_NLINK 4U
#define STATX_UID 8U
#define STATX_GID 0x10U
#define STATX_ATIME 0x20U
#define STATX_MTIME 0x40U
#define STATX_CTIME 0x80U
#define STATX_INO 0x100U
#define STATX_SIZE 0x200U
#define STATX_BLOCKS 0x400U
#define STATX_BASIC_STATS 0x7ffU
#define STATX_BTIME 0x800U
#define STATX_ALL 0xfffU

struct statx_timestamp {
	int64_t tv_sec;
	uint32_t tv_nsec, __pad;
};

struct statx {
	uint32_t stx_mask;
	uint32_t stx_blksize;
	uint64_t stx_attributes;
	uint32_t stx_nlink;
	uint32_t stx_uid;
	uint32_t stx_gid;
	uint16_t stx_mode;
	uint16_t __pad0[1];
	uint64_t stx_ino;
	uint64_t stx_size;
	uint64_t stx_blocks;
	uint64_t stx_attributes_mask;
	struct statx_timestamp stx_atime;
	struct statx_timestamp stx_btime;
	struct statx_timestamp stx_ctime;
	struct statx_timestamp stx_mtime;
	uint32_t stx_rdev_major;
	uint32_t stx_rdev_minor;
	uint32_t stx_dev_major;
	uint32_t stx_dev_minor;
	uint64_t __pad1[14];
};

int statx(int, const char *__restrict, int, unsigned, struct statx *__restrict);
#endif

#if defined(_LARGEFILE64_SOURCE)
#define stat64 stat
#define fstat64 fstat
#define lstat64 lstat
#define fstatat64 fstatat
#define blkcnt64_t blkcnt_t
#define fsblkcnt64_t fsblkcnt_t
#define fsfilcnt64_t fsfilcnt_t
#define ino64_t ino_t
#define off64_t off_t
#endif

#if _REDIR_TIME64
__REDIR(stat, __stat_time64);
__REDIR(fstat, __fstat_time64);
__REDIR(lstat, __lstat_time64);
__REDIR(fstatat, __fstatat_time64);
__REDIR(futimens, __futimens_time64);
__REDIR(utimensat, __utimensat_time64);
#endif

#ifdef __cplusplus
}
#endif
#endif


