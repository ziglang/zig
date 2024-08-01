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
#ifndef _UAPI_LINUX_SUNRPC_DEBUG_H_
#define _UAPI_LINUX_SUNRPC_DEBUG_H_
#define RPCDBG_XPRT 0x0001
#define RPCDBG_CALL 0x0002
#define RPCDBG_DEBUG 0x0004
#define RPCDBG_NFS 0x0008
#define RPCDBG_AUTH 0x0010
#define RPCDBG_BIND 0x0020
#define RPCDBG_SCHED 0x0040
#define RPCDBG_TRANS 0x0080
#define RPCDBG_SVCXPRT 0x0100
#define RPCDBG_SVCDSP 0x0200
#define RPCDBG_MISC 0x0400
#define RPCDBG_CACHE 0x0800
#define RPCDBG_ALL 0x7fff
enum {
  CTL_RPCDEBUG = 1,
  CTL_NFSDEBUG,
  CTL_NFSDDEBUG,
  CTL_NLMDEBUG,
  CTL_SLOTTABLE_UDP,
  CTL_SLOTTABLE_TCP,
  CTL_MIN_RESVPORT,
  CTL_MAX_RESVPORT,
};
#endif