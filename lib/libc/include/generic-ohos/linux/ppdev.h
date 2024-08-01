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
#ifndef _UAPI_LINUX_PPDEV_H
#define _UAPI_LINUX_PPDEV_H
#define PP_IOCTL 'p'
#define PPSETMODE _IOW(PP_IOCTL, 0x80, int)
#define PPRSTATUS _IOR(PP_IOCTL, 0x81, unsigned char)
#define PPWSTATUS OBSOLETE__IOW(PP_IOCTL, 0x82, unsigned char)
#define PPRCONTROL _IOR(PP_IOCTL, 0x83, unsigned char)
#define PPWCONTROL _IOW(PP_IOCTL, 0x84, unsigned char)
struct ppdev_frob_struct {
  unsigned char mask;
  unsigned char val;
};
#define PPFCONTROL _IOW(PP_IOCTL, 0x8e, struct ppdev_frob_struct)
#define PPRDATA _IOR(PP_IOCTL, 0x85, unsigned char)
#define PPWDATA _IOW(PP_IOCTL, 0x86, unsigned char)
#define PPRECONTROL OBSOLETE__IOR(PP_IOCTL, 0x87, unsigned char)
#define PPWECONTROL OBSOLETE__IOW(PP_IOCTL, 0x88, unsigned char)
#define PPRFIFO OBSOLETE__IOR(PP_IOCTL, 0x89, unsigned char)
#define PPWFIFO OBSOLETE__IOW(PP_IOCTL, 0x8a, unsigned char)
#define PPCLAIM _IO(PP_IOCTL, 0x8b)
#define PPRELEASE _IO(PP_IOCTL, 0x8c)
#define PPYIELD _IO(PP_IOCTL, 0x8d)
#define PPEXCL _IO(PP_IOCTL, 0x8f)
#define PPDATADIR _IOW(PP_IOCTL, 0x90, int)
#define PPNEGOT _IOW(PP_IOCTL, 0x91, int)
#define PPWCTLONIRQ _IOW(PP_IOCTL, 0x92, unsigned char)
#define PPCLRIRQ _IOR(PP_IOCTL, 0x93, int)
#define PPSETPHASE _IOW(PP_IOCTL, 0x94, int)
#define PPGETTIME _IOR(PP_IOCTL, 0x95, struct timeval)
#define PPSETTIME _IOW(PP_IOCTL, 0x96, struct timeval)
#define PPGETMODES _IOR(PP_IOCTL, 0x97, unsigned int)
#define PPGETMODE _IOR(PP_IOCTL, 0x98, int)
#define PPGETPHASE _IOR(PP_IOCTL, 0x99, int)
#define PPGETFLAGS _IOR(PP_IOCTL, 0x9a, int)
#define PPSETFLAGS _IOW(PP_IOCTL, 0x9b, int)
#define PP_FASTWRITE (1 << 2)
#define PP_FASTREAD (1 << 3)
#define PP_W91284PIC (1 << 4)
#define PP_FLAGMASK (PP_FASTWRITE | PP_FASTREAD | PP_W91284PIC)
#endif