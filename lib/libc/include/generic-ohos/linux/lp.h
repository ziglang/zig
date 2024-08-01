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
#ifndef _UAPI_LINUX_LP_H
#define _UAPI_LINUX_LP_H
#include <linux/types.h>
#include <linux/ioctl.h>
#define LP_EXIST 0x0001
#define LP_SELEC 0x0002
#define LP_BUSY 0x0004
#define LP_BUSY_BIT_POS 2
#define LP_OFFL 0x0008
#define LP_NOPA 0x0010
#define LP_ERR 0x0020
#define LP_ABORT 0x0040
#define LP_CAREFUL 0x0080
#define LP_ABORTOPEN 0x0100
#define LP_TRUST_IRQ_ 0x0200
#define LP_NO_REVERSE 0x0400
#define LP_DATA_AVAIL 0x0800
#define LP_PBUSY 0x80
#define LP_PACK 0x40
#define LP_POUTPA 0x20
#define LP_PSELECD 0x10
#define LP_PERRORP 0x08
#define LP_INIT_CHAR 1000
#define LP_INIT_WAIT 1
#define LP_INIT_TIME 2
#define LPCHAR 0x0601
#define LPTIME 0x0602
#define LPABORT 0x0604
#define LPSETIRQ 0x0605
#define LPGETIRQ 0x0606
#define LPWAIT 0x0608
#define LPCAREFUL 0x0609
#define LPABORTOPEN 0x060a
#define LPGETSTATUS 0x060b
#define LPRESET 0x060c
#ifdef LP_STATS
#define LPGETSTATS 0x060d
#endif
#define LPGETFLAGS 0x060e
#define LPSETTIMEOUT_OLD 0x060f
#define LPSETTIMEOUT_NEW _IOW(0x6, 0xf, __s64[2])
#if __BITS_PER_LONG == 64
#define LPSETTIMEOUT LPSETTIMEOUT_OLD
#else
#define LPSETTIMEOUT (sizeof(time_t) > sizeof(__kernel_long_t) ? LPSETTIMEOUT_NEW : LPSETTIMEOUT_OLD)
#endif
#define LP_TIMEOUT_INTERRUPT (60 * HZ)
#define LP_TIMEOUT_POLLED (10 * HZ)
#endif