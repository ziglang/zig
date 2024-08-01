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
#ifndef _UAPI__ADB_H
#define _UAPI__ADB_H
#define ADB_BUSRESET 0
#define ADB_FLUSH(id) (0x01 | ((id) << 4))
#define ADB_WRITEREG(id,reg) (0x08 | (reg) | ((id) << 4))
#define ADB_READREG(id,reg) (0x0C | (reg) | ((id) << 4))
#define ADB_DONGLE 1
#define ADB_KEYBOARD 2
#define ADB_MOUSE 3
#define ADB_TABLET 4
#define ADB_MODEM 5
#define ADB_MISC 7
#define ADB_RET_OK 0
#define ADB_RET_TIMEOUT 3
#define ADB_PACKET 0
#define CUDA_PACKET 1
#define ERROR_PACKET 2
#define TIMER_PACKET 3
#define POWER_PACKET 4
#define MACIIC_PACKET 5
#define PMU_PACKET 6
#define ADB_QUERY 7
#define ADB_QUERY_GETDEVINFO 1
#endif