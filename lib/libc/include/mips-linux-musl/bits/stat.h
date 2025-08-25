/* copied from kernel definition, but with padding replaced
 * by the corresponding correctly-sized userspace types. */

struct stat {
	dev_t st_dev;
	long __st_padding1[2];
	ino_t st_ino;
	mode_t st_mode;
	nlink_t st_nlink;
	uid_t st_uid;
	gid_t st_gid;
	dev_t st_rdev;
	long __st_padding2[2];
	off_t st_size;
	struct {
		long tv_sec;
		long tv_nsec;
	} __st_atim32, __st_mtim32, __st_ctim32;
	blksize_t st_blksize;
	long __st_padding3;
	blkcnt_t st_blocks;
	struct timespec st_atim;
	struct timespec st_mtim;
	struct timespec st_ctim;
	long __st_padding4[2];
};