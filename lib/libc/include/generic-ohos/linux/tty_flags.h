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
#ifndef _LINUX_TTY_FLAGS_H
#define _LINUX_TTY_FLAGS_H
#define ASYNCB_HUP_NOTIFY 0
#define ASYNCB_FOURPORT 1
#define ASYNCB_SAK 2
#define ASYNCB_SPLIT_TERMIOS 3
#define ASYNCB_SPD_HI 4
#define ASYNCB_SPD_VHI 5
#define ASYNCB_SKIP_TEST 6
#define ASYNCB_AUTO_IRQ 7
#define ASYNCB_SESSION_LOCKOUT 8
#define ASYNCB_PGRP_LOCKOUT 9
#define ASYNCB_CALLOUT_NOHUP 10
#define ASYNCB_HARDPPS_CD 11
#define ASYNCB_SPD_SHI 12
#define ASYNCB_LOW_LATENCY 13
#define ASYNCB_BUGGY_UART 14
#define ASYNCB_AUTOPROBE 15
#define ASYNCB_MAGIC_MULTIPLIER 16
#define ASYNCB_LAST_USER 16
#ifndef _KERNEL_
#define ASYNCB_INITIALIZED 31
#define ASYNCB_SUSPENDED 30
#define ASYNCB_NORMAL_ACTIVE 29
#define ASYNCB_BOOT_AUTOCONF 28
#define ASYNCB_CLOSING 27
#define ASYNCB_CTS_FLOW 26
#define ASYNCB_CHECK_CD 25
#define ASYNCB_SHARE_IRQ 24
#define ASYNCB_CONS_FLOW 23
#define ASYNCB_FIRST_KERNEL 22
#endif
#define ASYNC_HUP_NOTIFY (1U << ASYNCB_HUP_NOTIFY)
#define ASYNC_SUSPENDED (1U << ASYNCB_SUSPENDED)
#define ASYNC_FOURPORT (1U << ASYNCB_FOURPORT)
#define ASYNC_SAK (1U << ASYNCB_SAK)
#define ASYNC_SPLIT_TERMIOS (1U << ASYNCB_SPLIT_TERMIOS)
#define ASYNC_SPD_HI (1U << ASYNCB_SPD_HI)
#define ASYNC_SPD_VHI (1U << ASYNCB_SPD_VHI)
#define ASYNC_SKIP_TEST (1U << ASYNCB_SKIP_TEST)
#define ASYNC_AUTO_IRQ (1U << ASYNCB_AUTO_IRQ)
#define ASYNC_SESSION_LOCKOUT (1U << ASYNCB_SESSION_LOCKOUT)
#define ASYNC_PGRP_LOCKOUT (1U << ASYNCB_PGRP_LOCKOUT)
#define ASYNC_CALLOUT_NOHUP (1U << ASYNCB_CALLOUT_NOHUP)
#define ASYNC_HARDPPS_CD (1U << ASYNCB_HARDPPS_CD)
#define ASYNC_SPD_SHI (1U << ASYNCB_SPD_SHI)
#define ASYNC_LOW_LATENCY (1U << ASYNCB_LOW_LATENCY)
#define ASYNC_BUGGY_UART (1U << ASYNCB_BUGGY_UART)
#define ASYNC_AUTOPROBE (1U << ASYNCB_AUTOPROBE)
#define ASYNC_MAGIC_MULTIPLIER (1U << ASYNCB_MAGIC_MULTIPLIER)
#define ASYNC_FLAGS ((1U << (ASYNCB_LAST_USER + 1)) - 1)
#define ASYNC_DEPRECATED (ASYNC_SESSION_LOCKOUT | ASYNC_PGRP_LOCKOUT | ASYNC_CALLOUT_NOHUP | ASYNC_AUTOPROBE)
#define ASYNC_USR_MASK (ASYNC_SPD_MASK | ASYNC_CALLOUT_NOHUP | ASYNC_LOW_LATENCY)
#define ASYNC_SPD_CUST (ASYNC_SPD_HI | ASYNC_SPD_VHI)
#define ASYNC_SPD_WARP (ASYNC_SPD_HI | ASYNC_SPD_SHI)
#define ASYNC_SPD_MASK (ASYNC_SPD_HI | ASYNC_SPD_VHI | ASYNC_SPD_SHI)
#ifndef _KERNEL_
#define ASYNC_INITIALIZED (1U << ASYNCB_INITIALIZED)
#define ASYNC_NORMAL_ACTIVE (1U << ASYNCB_NORMAL_ACTIVE)
#define ASYNC_BOOT_AUTOCONF (1U << ASYNCB_BOOT_AUTOCONF)
#define ASYNC_CLOSING (1U << ASYNCB_CLOSING)
#define ASYNC_CTS_FLOW (1U << ASYNCB_CTS_FLOW)
#define ASYNC_CHECK_CD (1U << ASYNCB_CHECK_CD)
#define ASYNC_SHARE_IRQ (1U << ASYNCB_SHARE_IRQ)
#define ASYNC_CONS_FLOW (1U << ASYNCB_CONS_FLOW)
#define ASYNC_INTERNAL_FLAGS (~((1U << ASYNCB_FIRST_KERNEL) - 1))
#endif
#endif