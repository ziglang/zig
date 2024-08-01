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
#ifndef _UAPI_LINUX_PMU_H
#define _UAPI_LINUX_PMU_H
#define PMU_DRIVER_VERSION 2
#define PMU_POWER_CTRL0 0x10
#define PMU_POWER_CTRL 0x11
#define PMU_ADB_CMD 0x20
#define PMU_ADB_POLL_OFF 0x21
#define PMU_WRITE_XPRAM 0x32
#define PMU_WRITE_NVRAM 0x33
#define PMU_READ_XPRAM 0x3a
#define PMU_READ_NVRAM 0x3b
#define PMU_SET_RTC 0x30
#define PMU_READ_RTC 0x38
#define PMU_SET_VOLBUTTON 0x40
#define PMU_BACKLIGHT_BRIGHT 0x41
#define PMU_GET_VOLBUTTON 0x48
#define PMU_PCEJECT 0x4c
#define PMU_BATTERY_STATE 0x6b
#define PMU_SMART_BATTERY_STATE 0x6f
#define PMU_SET_INTR_MASK 0x70
#define PMU_INT_ACK 0x78
#define PMU_SHUTDOWN 0x7e
#define PMU_CPU_SPEED 0x7d
#define PMU_SLEEP 0x7f
#define PMU_POWER_EVENTS 0x8f
#define PMU_I2C_CMD 0x9a
#define PMU_RESET 0xd0
#define PMU_GET_BRIGHTBUTTON 0xd9
#define PMU_GET_COVER 0xdc
#define PMU_SYSTEM_READY 0xdf
#define PMU_GET_VERSION 0xea
#define PMU_POW0_ON 0x80
#define PMU_POW0_OFF 0x00
#define PMU_POW0_HARD_DRIVE 0x04
#define PMU_POW_ON 0x80
#define PMU_POW_OFF 0x00
#define PMU_POW_BACKLIGHT 0x01
#define PMU_POW_CHARGER 0x02
#define PMU_POW_IRLED 0x04
#define PMU_POW_MEDIABAY 0x08
#define PMU_INT_PCEJECT 0x04
#define PMU_INT_SNDBRT 0x08
#define PMU_INT_ADB 0x10
#define PMU_INT_BATTERY 0x20
#define PMU_INT_ENVIRONMENT 0x40
#define PMU_INT_TICK 0x80
#define PMU_INT_ADB_AUTO 0x04
#define PMU_INT_WAITING_CHARGER 0x01
#define PMU_INT_AUTO_SRQ_POLL 0x02
#define PMU_ENV_LID_CLOSED 0x01
#define PMU_I2C_MODE_SIMPLE 0
#define PMU_I2C_MODE_STDSUB 1
#define PMU_I2C_MODE_COMBINED 2
#define PMU_I2C_BUS_STATUS 0
#define PMU_I2C_BUS_SYSCLK 1
#define PMU_I2C_BUS_POWER 2
#define PMU_I2C_STATUS_OK 0
#define PMU_I2C_STATUS_DATAREAD 1
#define PMU_I2C_STATUS_BUSY 0xfe
enum {
  PMU_UNKNOWN,
  PMU_OHARE_BASED,
  PMU_HEATHROW_BASED,
  PMU_PADDINGTON_BASED,
  PMU_KEYLARGO_BASED,
  PMU_68K_V1,
  PMU_68K_V2,
};
enum {
  PMU_PWR_GET_POWERUP_EVENTS = 0x00,
  PMU_PWR_SET_POWERUP_EVENTS = 0x01,
  PMU_PWR_CLR_POWERUP_EVENTS = 0x02,
  PMU_PWR_GET_WAKEUP_EVENTS = 0x03,
  PMU_PWR_SET_WAKEUP_EVENTS = 0x04,
  PMU_PWR_CLR_WAKEUP_EVENTS = 0x05,
};
enum {
  PMU_PWR_WAKEUP_KEY = 0x01,
  PMU_PWR_WAKEUP_AC_INSERT = 0x02,
  PMU_PWR_WAKEUP_AC_CHANGE = 0x04,
  PMU_PWR_WAKEUP_LID_OPEN = 0x08,
  PMU_PWR_WAKEUP_RING = 0x10,
};
#include <linux/ioctl.h>
#define PMU_IOC_SLEEP _IO('B', 0)
#define PMU_IOC_GET_BACKLIGHT _IOR('B', 1, size_t)
#define PMU_IOC_SET_BACKLIGHT _IOW('B', 2, size_t)
#define PMU_IOC_GET_MODEL _IOR('B', 3, size_t)
#define PMU_IOC_HAS_ADB _IOR('B', 4, size_t)
#define PMU_IOC_CAN_SLEEP _IOR('B', 5, size_t)
#define PMU_IOC_GRAB_BACKLIGHT _IOR('B', 6, size_t)
#endif