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
#ifndef _UAPI_SONYPI_H_
#define _UAPI_SONYPI_H_
#include <linux/types.h>
#define SONYPI_EVENT_IGNORE 0
#define SONYPI_EVENT_JOGDIAL_DOWN 1
#define SONYPI_EVENT_JOGDIAL_UP 2
#define SONYPI_EVENT_JOGDIAL_DOWN_PRESSED 3
#define SONYPI_EVENT_JOGDIAL_UP_PRESSED 4
#define SONYPI_EVENT_JOGDIAL_PRESSED 5
#define SONYPI_EVENT_JOGDIAL_RELEASED 6
#define SONYPI_EVENT_CAPTURE_PRESSED 7
#define SONYPI_EVENT_CAPTURE_RELEASED 8
#define SONYPI_EVENT_CAPTURE_PARTIALPRESSED 9
#define SONYPI_EVENT_CAPTURE_PARTIALRELEASED 10
#define SONYPI_EVENT_FNKEY_ESC 11
#define SONYPI_EVENT_FNKEY_F1 12
#define SONYPI_EVENT_FNKEY_F2 13
#define SONYPI_EVENT_FNKEY_F3 14
#define SONYPI_EVENT_FNKEY_F4 15
#define SONYPI_EVENT_FNKEY_F5 16
#define SONYPI_EVENT_FNKEY_F6 17
#define SONYPI_EVENT_FNKEY_F7 18
#define SONYPI_EVENT_FNKEY_F8 19
#define SONYPI_EVENT_FNKEY_F9 20
#define SONYPI_EVENT_FNKEY_F10 21
#define SONYPI_EVENT_FNKEY_F11 22
#define SONYPI_EVENT_FNKEY_F12 23
#define SONYPI_EVENT_FNKEY_1 24
#define SONYPI_EVENT_FNKEY_2 25
#define SONYPI_EVENT_FNKEY_D 26
#define SONYPI_EVENT_FNKEY_E 27
#define SONYPI_EVENT_FNKEY_F 28
#define SONYPI_EVENT_FNKEY_S 29
#define SONYPI_EVENT_FNKEY_B 30
#define SONYPI_EVENT_BLUETOOTH_PRESSED 31
#define SONYPI_EVENT_PKEY_P1 32
#define SONYPI_EVENT_PKEY_P2 33
#define SONYPI_EVENT_PKEY_P3 34
#define SONYPI_EVENT_BACK_PRESSED 35
#define SONYPI_EVENT_LID_CLOSED 36
#define SONYPI_EVENT_LID_OPENED 37
#define SONYPI_EVENT_BLUETOOTH_ON 38
#define SONYPI_EVENT_BLUETOOTH_OFF 39
#define SONYPI_EVENT_HELP_PRESSED 40
#define SONYPI_EVENT_FNKEY_ONLY 41
#define SONYPI_EVENT_JOGDIAL_FAST_DOWN 42
#define SONYPI_EVENT_JOGDIAL_FAST_UP 43
#define SONYPI_EVENT_JOGDIAL_FAST_DOWN_PRESSED 44
#define SONYPI_EVENT_JOGDIAL_FAST_UP_PRESSED 45
#define SONYPI_EVENT_JOGDIAL_VFAST_DOWN 46
#define SONYPI_EVENT_JOGDIAL_VFAST_UP 47
#define SONYPI_EVENT_JOGDIAL_VFAST_DOWN_PRESSED 48
#define SONYPI_EVENT_JOGDIAL_VFAST_UP_PRESSED 49
#define SONYPI_EVENT_ZOOM_PRESSED 50
#define SONYPI_EVENT_THUMBPHRASE_PRESSED 51
#define SONYPI_EVENT_MEYE_FACE 52
#define SONYPI_EVENT_MEYE_OPPOSITE 53
#define SONYPI_EVENT_MEMORYSTICK_INSERT 54
#define SONYPI_EVENT_MEMORYSTICK_EJECT 55
#define SONYPI_EVENT_ANYBUTTON_RELEASED 56
#define SONYPI_EVENT_BATTERY_INSERT 57
#define SONYPI_EVENT_BATTERY_REMOVE 58
#define SONYPI_EVENT_FNKEY_RELEASED 59
#define SONYPI_EVENT_WIRELESS_ON 60
#define SONYPI_EVENT_WIRELESS_OFF 61
#define SONYPI_EVENT_ZOOM_IN_PRESSED 62
#define SONYPI_EVENT_ZOOM_OUT_PRESSED 63
#define SONYPI_EVENT_CD_EJECT_PRESSED 64
#define SONYPI_EVENT_MODEKEY_PRESSED 65
#define SONYPI_EVENT_PKEY_P4 66
#define SONYPI_EVENT_PKEY_P5 67
#define SONYPI_EVENT_SETTINGKEY_PRESSED 68
#define SONYPI_EVENT_VOLUME_INC_PRESSED 69
#define SONYPI_EVENT_VOLUME_DEC_PRESSED 70
#define SONYPI_EVENT_BRIGHTNESS_PRESSED 71
#define SONYPI_EVENT_MEDIA_PRESSED 72
#define SONYPI_EVENT_VENDOR_PRESSED 73
#define SONYPI_IOCGBRT _IOR('v', 0, __u8)
#define SONYPI_IOCSBRT _IOW('v', 0, __u8)
#define SONYPI_IOCGBAT1CAP _IOR('v', 2, __u16)
#define SONYPI_IOCGBAT1REM _IOR('v', 3, __u16)
#define SONYPI_IOCGBAT2CAP _IOR('v', 4, __u16)
#define SONYPI_IOCGBAT2REM _IOR('v', 5, __u16)
#define SONYPI_BFLAGS_B1 0x01
#define SONYPI_BFLAGS_B2 0x02
#define SONYPI_BFLAGS_AC 0x04
#define SONYPI_IOCGBATFLAGS _IOR('v', 7, __u8)
#define SONYPI_IOCGBLUE _IOR('v', 8, __u8)
#define SONYPI_IOCSBLUE _IOW('v', 9, __u8)
#define SONYPI_IOCGFAN _IOR('v', 10, __u8)
#define SONYPI_IOCSFAN _IOW('v', 11, __u8)
#define SONYPI_IOCGTEMP _IOR('v', 12, __u8)
#endif