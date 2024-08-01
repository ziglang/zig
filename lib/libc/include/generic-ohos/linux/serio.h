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
#ifndef _UAPI_SERIO_H
#define _UAPI_SERIO_H
#include <linux/const.h>
#include <linux/ioctl.h>
#define SPIOCSTYPE _IOW('q', 0x01, unsigned long)
#define SERIO_TIMEOUT _BITUL(0)
#define SERIO_PARITY _BITUL(1)
#define SERIO_FRAME _BITUL(2)
#define SERIO_OOB_DATA _BITUL(3)
#define SERIO_XT 0x00
#define SERIO_8042 0x01
#define SERIO_RS232 0x02
#define SERIO_HIL_MLC 0x03
#define SERIO_PS_PSTHRU 0x05
#define SERIO_8042_XL 0x06
#define SERIO_UNKNOWN 0x00
#define SERIO_MSC 0x01
#define SERIO_SUN 0x02
#define SERIO_MS 0x03
#define SERIO_MP 0x04
#define SERIO_MZ 0x05
#define SERIO_MZP 0x06
#define SERIO_MZPP 0x07
#define SERIO_VSXXXAA 0x08
#define SERIO_SUNKBD 0x10
#define SERIO_WARRIOR 0x18
#define SERIO_SPACEORB 0x19
#define SERIO_MAGELLAN 0x1a
#define SERIO_SPACEBALL 0x1b
#define SERIO_GUNZE 0x1c
#define SERIO_IFORCE 0x1d
#define SERIO_STINGER 0x1e
#define SERIO_NEWTON 0x1f
#define SERIO_STOWAWAY 0x20
#define SERIO_H3600 0x21
#define SERIO_PS2SER 0x22
#define SERIO_TWIDKBD 0x23
#define SERIO_TWIDJOY 0x24
#define SERIO_HIL 0x25
#define SERIO_SNES232 0x26
#define SERIO_SEMTECH 0x27
#define SERIO_LKKBD 0x28
#define SERIO_ELO 0x29
#define SERIO_MICROTOUCH 0x30
#define SERIO_PENMOUNT 0x31
#define SERIO_TOUCHRIGHT 0x32
#define SERIO_TOUCHWIN 0x33
#define SERIO_TAOSEVM 0x34
#define SERIO_FUJITSU 0x35
#define SERIO_ZHENHUA 0x36
#define SERIO_INEXIO 0x37
#define SERIO_TOUCHIT213 0x38
#define SERIO_W8001 0x39
#define SERIO_DYNAPRO 0x3a
#define SERIO_HAMPSHIRE 0x3b
#define SERIO_PS2MULT 0x3c
#define SERIO_TSC40 0x3d
#define SERIO_WACOM_IV 0x3e
#define SERIO_EGALAX 0x3f
#define SERIO_PULSE8_CEC 0x40
#define SERIO_RAINSHADOW_CEC 0x41
#define SERIO_FSIA6B 0x42
#endif