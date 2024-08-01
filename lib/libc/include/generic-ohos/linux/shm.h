/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _UAPI_LINUX_SHM_H_
#define _UAPI_LINUX_SHM_H_
#include <linux/ipc.h>
#include <linux/errno.h>
#include <asm-generic/hugetlb_encode.h>
#include <unistd.h>
#define SHMMIN 1
#define SHMMNI 4096
#define SHMMAX (ULONG_MAX - (1UL << 24))
#define SHMALL (ULONG_MAX - (1UL << 24))
#define SHMSEG SHMMNI
struct __kernel_legacy_shmid_ds {
  struct __kernel_legacy_ipc_perm shm_perm;
  int shm_segsz;
  __kernel_old_time_t shm_atime;
  __kernel_old_time_t shm_dtime;
  __kernel_old_time_t shm_ctime;
  __kernel_ipc_pid_t shm_cpid;
  __kernel_ipc_pid_t shm_lpid;
  unsigned short shm_nattch;
  unsigned short shm_unused;
  void * shm_unused2;
  void * shm_unused3;
};
#include <asm/shmbuf.h>
#define SHM_R 0400
#define SHM_W 0200
#define SHM_HUGETLB 04000
#define SHM_NORESERVE 010000
#define SHM_HUGE_SHIFT HUGETLB_FLAG_ENCODE_SHIFT
#define SHM_HUGE_MASK HUGETLB_FLAG_ENCODE_MASK
#define SHM_HUGE_64KB HUGETLB_FLAG_ENCODE_64KB
#define SHM_HUGE_512KB HUGETLB_FLAG_ENCODE_512KB
#define SHM_HUGE_1MB HUGETLB_FLAG_ENCODE_1MB
#define SHM_HUGE_2MB HUGETLB_FLAG_ENCODE_2MB
#define SHM_HUGE_8MB HUGETLB_FLAG_ENCODE_8MB
#define SHM_HUGE_16MB HUGETLB_FLAG_ENCODE_16MB
#define SHM_HUGE_32MB HUGETLB_FLAG_ENCODE_32MB
#define SHM_HUGE_256MB HUGETLB_FLAG_ENCODE_256MB
#define SHM_HUGE_512MB HUGETLB_FLAG_ENCODE_512MB
#define SHM_HUGE_1GB HUGETLB_FLAG_ENCODE_1GB
#define SHM_HUGE_2GB HUGETLB_FLAG_ENCODE_2GB
#define SHM_HUGE_16GB HUGETLB_FLAG_ENCODE_16GB
#define SHM_RDONLY 010000
#define SHM_RND 020000
#define SHM_REMAP 040000
#define SHM_EXEC 0100000
#define SHM_LOCK 11
#define SHM_UNLOCK 12
#define SHM_STAT 13
#define SHM_INFO 14
#define SHM_STAT_ANY 15
struct shminfo {
  int shmmax;
  int shmmin;
  int shmmni;
  int shmseg;
  int shmall;
};
struct shm_info {
  int used_ids;
  __kernel_ulong_t shm_tot;
  __kernel_ulong_t shm_rss;
  __kernel_ulong_t shm_swp;
  __kernel_ulong_t swap_attempts;
  __kernel_ulong_t swap_successes;
};
#endif