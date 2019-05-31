#include <string.h>
#include <bits/alltypes.h>

struct stat {
	dev_t st_dev;
	long __pad1[2];
	ino_t st_ino;
	mode_t st_mode;
	nlink_t st_nlink;
	uid_t st_uid;
	gid_t st_gid;
	dev_t st_rdev;
	long __pad2[2];
	off_t st_size;
	struct timespec st_atim;
	struct timespec st_mtim;
	struct timespec st_ctim;
	blksize_t st_blksize;
	long __pad3;
	blkcnt_t st_blocks;
	long __pad4[14];
};
