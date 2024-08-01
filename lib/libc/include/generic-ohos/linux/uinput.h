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
#ifndef _UAPI__UINPUT_H_
#define _UAPI__UINPUT_H_
#include <linux/types.h>
#include <linux/input.h>
#define UINPUT_VERSION 5
#define UINPUT_MAX_NAME_SIZE 80
struct uinput_ff_upload {
  __u32 request_id;
  __s32 retval;
  struct ff_effect effect;
  struct ff_effect old;
};
struct uinput_ff_erase {
  __u32 request_id;
  __s32 retval;
  __u32 effect_id;
};
#define UINPUT_IOCTL_BASE 'U'
#define UI_DEV_CREATE _IO(UINPUT_IOCTL_BASE, 1)
#define UI_DEV_DESTROY _IO(UINPUT_IOCTL_BASE, 2)
struct uinput_setup {
  struct input_id id;
  char name[UINPUT_MAX_NAME_SIZE];
  __u32 ff_effects_max;
};
#define UI_DEV_SETUP _IOW(UINPUT_IOCTL_BASE, 3, struct uinput_setup)
struct uinput_abs_setup {
  __u16 code;
  struct input_absinfo absinfo;
};
#define UI_ABS_SETUP _IOW(UINPUT_IOCTL_BASE, 4, struct uinput_abs_setup)
#define UI_SET_EVBIT _IOW(UINPUT_IOCTL_BASE, 100, int)
#define UI_SET_KEYBIT _IOW(UINPUT_IOCTL_BASE, 101, int)
#define UI_SET_RELBIT _IOW(UINPUT_IOCTL_BASE, 102, int)
#define UI_SET_ABSBIT _IOW(UINPUT_IOCTL_BASE, 103, int)
#define UI_SET_MSCBIT _IOW(UINPUT_IOCTL_BASE, 104, int)
#define UI_SET_LEDBIT _IOW(UINPUT_IOCTL_BASE, 105, int)
#define UI_SET_SNDBIT _IOW(UINPUT_IOCTL_BASE, 106, int)
#define UI_SET_FFBIT _IOW(UINPUT_IOCTL_BASE, 107, int)
#define UI_SET_PHYS _IOW(UINPUT_IOCTL_BASE, 108, char *)
#define UI_SET_SWBIT _IOW(UINPUT_IOCTL_BASE, 109, int)
#define UI_SET_PROPBIT _IOW(UINPUT_IOCTL_BASE, 110, int)
#define UI_BEGIN_FF_UPLOAD _IOWR(UINPUT_IOCTL_BASE, 200, struct uinput_ff_upload)
#define UI_END_FF_UPLOAD _IOW(UINPUT_IOCTL_BASE, 201, struct uinput_ff_upload)
#define UI_BEGIN_FF_ERASE _IOWR(UINPUT_IOCTL_BASE, 202, struct uinput_ff_erase)
#define UI_END_FF_ERASE _IOW(UINPUT_IOCTL_BASE, 203, struct uinput_ff_erase)
#define UI_GET_SYSNAME(len) _IOC(_IOC_READ, UINPUT_IOCTL_BASE, 44, len)
#define UI_GET_VERSION _IOR(UINPUT_IOCTL_BASE, 45, unsigned int)
#define EV_UINPUT 0x0101
#define UI_FF_UPLOAD 1
#define UI_FF_ERASE 2
struct uinput_user_dev {
  char name[UINPUT_MAX_NAME_SIZE];
  struct input_id id;
  __u32 ff_effects_max;
  __s32 absmax[ABS_CNT];
  __s32 absmin[ABS_CNT];
  __s32 absfuzz[ABS_CNT];
  __s32 absflat[ABS_CNT];
};
#endif