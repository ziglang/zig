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
#ifndef _UAPI_INPUT_H
#define _UAPI_INPUT_H
#include <sys/time.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <linux/types.h>
#include "input-event-codes.h"
struct input_event {
#if __BITS_PER_LONG != 32 || !defined(__USE_TIME_BITS64)
  struct timeval time;
#define input_event_sec time.tv_sec
#define input_event_usec time.tv_usec
#else
  __kernel_ulong_t __sec;
#if defined(__sparc__) && defined(__arch64__)
  unsigned int __usec;
  unsigned int __pad;
#else
  __kernel_ulong_t __usec;
#endif
#define input_event_sec __sec
#define input_event_usec __usec
#endif
  __u16 type;
  __u16 code;
  __s32 value;
};
#define EV_VERSION 0x010001
struct input_id {
  __u16 bustype;
  __u16 vendor;
  __u16 product;
  __u16 version;
};
struct input_absinfo {
  __s32 value;
  __s32 minimum;
  __s32 maximum;
  __s32 fuzz;
  __s32 flat;
  __s32 resolution;
};
struct input_keymap_entry {
#define INPUT_KEYMAP_BY_INDEX (1 << 0)
  __u8 flags;
  __u8 len;
  __u16 index;
  __u32 keycode;
  __u8 scancode[32];
};
struct input_mask {
  __u32 type;
  __u32 codes_size;
  __u64 codes_ptr;
};
#define EVIOCGVERSION _IOR('E', 0x01, int)
#define EVIOCGID _IOR('E', 0x02, struct input_id)
#define EVIOCGREP _IOR('E', 0x03, unsigned int[2])
#define EVIOCSREP _IOW('E', 0x03, unsigned int[2])
#define EVIOCGKEYCODE _IOR('E', 0x04, unsigned int[2])
#define EVIOCGKEYCODE_V2 _IOR('E', 0x04, struct input_keymap_entry)
#define EVIOCSKEYCODE _IOW('E', 0x04, unsigned int[2])
#define EVIOCSKEYCODE_V2 _IOW('E', 0x04, struct input_keymap_entry)
#define EVIOCGNAME(len) _IOC(_IOC_READ, 'E', 0x06, len)
#define EVIOCGPHYS(len) _IOC(_IOC_READ, 'E', 0x07, len)
#define EVIOCGUNIQ(len) _IOC(_IOC_READ, 'E', 0x08, len)
#define EVIOCGPROP(len) _IOC(_IOC_READ, 'E', 0x09, len)
#define EVIOCGMTSLOTS(len) _IOC(_IOC_READ, 'E', 0x0a, len)
#define EVIOCGKEY(len) _IOC(_IOC_READ, 'E', 0x18, len)
#define EVIOCGLED(len) _IOC(_IOC_READ, 'E', 0x19, len)
#define EVIOCGSND(len) _IOC(_IOC_READ, 'E', 0x1a, len)
#define EVIOCGSW(len) _IOC(_IOC_READ, 'E', 0x1b, len)
#define EVIOCGBIT(ev,len) _IOC(_IOC_READ, 'E', 0x20 + (ev), len)
#define EVIOCGABS(abs) _IOR('E', 0x40 + (abs), struct input_absinfo)
#define EVIOCSABS(abs) _IOW('E', 0xc0 + (abs), struct input_absinfo)
#define EVIOCSFF _IOW('E', 0x80, struct ff_effect)
#define EVIOCRMFF _IOW('E', 0x81, int)
#define EVIOCGEFFECTS _IOR('E', 0x84, int)
#define EVIOCGRAB _IOW('E', 0x90, int)
#define EVIOCREVOKE _IOW('E', 0x91, int)
#define EVIOCGMASK _IOR('E', 0x92, struct input_mask)
#define EVIOCSMASK _IOW('E', 0x93, struct input_mask)
#define EVIOCSCLOCKID _IOW('E', 0xa0, int)
#define ID_BUS 0
#define ID_VENDOR 1
#define ID_PRODUCT 2
#define ID_VERSION 3
#define BUS_PCI 0x01
#define BUS_ISAPNP 0x02
#define BUS_USB 0x03
#define BUS_HIL 0x04
#define BUS_BLUETOOTH 0x05
#define BUS_VIRTUAL 0x06
#define BUS_ISA 0x10
#define BUS_I8042 0x11
#define BUS_XTKBD 0x12
#define BUS_RS232 0x13
#define BUS_GAMEPORT 0x14
#define BUS_PARPORT 0x15
#define BUS_AMIGA 0x16
#define BUS_ADB 0x17
#define BUS_I2C 0x18
#define BUS_HOST 0x19
#define BUS_GSC 0x1A
#define BUS_ATARI 0x1B
#define BUS_SPI 0x1C
#define BUS_RMI 0x1D
#define BUS_CEC 0x1E
#define BUS_INTEL_ISHTP 0x1F
#define MT_TOOL_FINGER 0x00
#define MT_TOOL_PEN 0x01
#define MT_TOOL_PALM 0x02
#define MT_TOOL_DIAL 0x0a
#define MT_TOOL_MAX 0x0f
#define FF_STATUS_STOPPED 0x00
#define FF_STATUS_PLAYING 0x01
#define FF_STATUS_MAX 0x01
struct ff_replay {
  __u16 length;
  __u16 delay;
};
struct ff_trigger {
  __u16 button;
  __u16 interval;
};
struct ff_envelope {
  __u16 attack_length;
  __u16 attack_level;
  __u16 fade_length;
  __u16 fade_level;
};
struct ff_constant_effect {
  __s16 level;
  struct ff_envelope envelope;
};
struct ff_ramp_effect {
  __s16 start_level;
  __s16 end_level;
  struct ff_envelope envelope;
};
struct ff_condition_effect {
  __u16 right_saturation;
  __u16 left_saturation;
  __s16 right_coeff;
  __s16 left_coeff;
  __u16 deadband;
  __s16 center;
};
struct ff_periodic_effect {
  __u16 waveform;
  __u16 period;
  __s16 magnitude;
  __s16 offset;
  __u16 phase;
  struct ff_envelope envelope;
  __u32 custom_len;
  __s16 __user * custom_data;
};
struct ff_rumble_effect {
  __u16 strong_magnitude;
  __u16 weak_magnitude;
};
struct ff_effect {
  __u16 type;
  __s16 id;
  __u16 direction;
  struct ff_trigger trigger;
  struct ff_replay replay;
  union {
    struct ff_constant_effect constant;
    struct ff_ramp_effect ramp;
    struct ff_periodic_effect periodic;
    struct ff_condition_effect condition[2];
    struct ff_rumble_effect rumble;
  } u;
};
#define FF_RUMBLE 0x50
#define FF_PERIODIC 0x51
#define FF_CONSTANT 0x52
#define FF_SPRING 0x53
#define FF_FRICTION 0x54
#define FF_DAMPER 0x55
#define FF_INERTIA 0x56
#define FF_RAMP 0x57
#define FF_EFFECT_MIN FF_RUMBLE
#define FF_EFFECT_MAX FF_RAMP
#define FF_SQUARE 0x58
#define FF_TRIANGLE 0x59
#define FF_SINE 0x5a
#define FF_SAW_UP 0x5b
#define FF_SAW_DOWN 0x5c
#define FF_CUSTOM 0x5d
#define FF_WAVEFORM_MIN FF_SQUARE
#define FF_WAVEFORM_MAX FF_CUSTOM
#define FF_GAIN 0x60
#define FF_AUTOCENTER 0x61
#define FF_MAX_EFFECTS FF_GAIN
#define FF_MAX 0x7f
#define FF_CNT (FF_MAX + 1)
#endif