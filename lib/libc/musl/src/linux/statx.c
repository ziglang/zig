#define _GNU_SOURCE
#include <sys/stat.h>
#include <string.h>
#include <syscall.h>
#include <sys/sysmacros.h>
#include <errno.h>

int statx(int dirfd, const char *restrict path, int flags, unsigned mask, struct statx *restrict stx)
{
	int ret = __syscall(SYS_statx, dirfd, path, flags, mask, stx);

#ifndef SYS_fstatat
	return __syscall_ret(ret);
#endif

	if (ret != -ENOSYS) return __syscall_ret(ret);

	struct stat st;
	ret = fstatat(dirfd, path, &st, flags);
	if (ret) return ret;

	stx->stx_dev_major = major(st.st_dev);
	stx->stx_dev_minor = minor(st.st_dev);
	stx->stx_ino = st.st_ino;
	stx->stx_mode = st.st_mode;
	stx->stx_nlink = st.st_nlink;
	stx->stx_uid = st.st_uid;
	stx->stx_gid = st.st_gid;
	stx->stx_size = st.st_size;
	stx->stx_blksize = st.st_blksize;
	stx->stx_blocks = st.st_blocks;
	stx->stx_atime.tv_sec = st.st_atim.tv_sec;
	stx->stx_atime.tv_nsec = st.st_atim.tv_nsec;
	stx->stx_mtime.tv_sec = st.st_mtim.tv_sec;
	stx->stx_mtime.tv_nsec = st.st_mtim.tv_nsec;
	stx->stx_ctime.tv_sec = st.st_ctim.tv_sec;
	stx->stx_ctime.tv_nsec = st.st_ctim.tv_nsec;
	stx->stx_btime = (struct statx_timestamp){.tv_sec=0, .tv_nsec=0};
	stx->stx_mask = STATX_BASIC_STATS;

	return 0;
}
