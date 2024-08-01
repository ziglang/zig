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
#ifndef _UAPI_LINUX_NFS_FS_H
#define _UAPI_LINUX_NFS_FS_H
#include <linux/magic.h>
#define NFS_DEF_UDP_TIMEO (11)
#define NFS_DEF_UDP_RETRANS (3)
#define NFS_DEF_TCP_TIMEO (600)
#define NFS_DEF_TCP_RETRANS (2)
#define NFS_MAX_UDP_TIMEOUT (60 * HZ)
#define NFS_MAX_TCP_TIMEOUT (600 * HZ)
#define NFS_DEF_ACREGMIN (3)
#define NFS_DEF_ACREGMAX (60)
#define NFS_DEF_ACDIRMIN (30)
#define NFS_DEF_ACDIRMAX (60)
#define FLUSH_SYNC 1
#define FLUSH_STABLE 4
#define FLUSH_LOWPRI 8
#define FLUSH_HIGHPRI 16
#define FLUSH_COND_STABLE 32
#define NFSDBG_VFS 0x0001
#define NFSDBG_DIRCACHE 0x0002
#define NFSDBG_LOOKUPCACHE 0x0004
#define NFSDBG_PAGECACHE 0x0008
#define NFSDBG_PROC 0x0010
#define NFSDBG_XDR 0x0020
#define NFSDBG_FILE 0x0040
#define NFSDBG_ROOT 0x0080
#define NFSDBG_CALLBACK 0x0100
#define NFSDBG_CLIENT 0x0200
#define NFSDBG_MOUNT 0x0400
#define NFSDBG_FSCACHE 0x0800
#define NFSDBG_PNFS 0x1000
#define NFSDBG_PNFS_LD 0x2000
#define NFSDBG_STATE 0x4000
#define NFSDBG_XATTRCACHE 0x8000
#define NFSDBG_ALL 0xFFFF
#endif