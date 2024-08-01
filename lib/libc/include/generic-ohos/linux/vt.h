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
#ifndef _UAPI_LINUX_VT_H
#define _UAPI_LINUX_VT_H
#define MIN_NR_CONSOLES 1
#define MAX_NR_CONSOLES 63
#define VT_OPENQRY 0x5600
struct vt_mode {
  char mode;
  char waitv;
  short relsig;
  short acqsig;
  short frsig;
};
#define VT_GETMODE 0x5601
#define VT_SETMODE 0x5602
#define VT_AUTO 0x00
#define VT_PROCESS 0x01
#define VT_ACKACQ 0x02
struct vt_stat {
  unsigned short v_active;
  unsigned short v_signal;
  unsigned short v_state;
};
#define VT_GETSTATE 0x5603
#define VT_SENDSIG 0x5604
#define VT_RELDISP 0x5605
#define VT_ACTIVATE 0x5606
#define VT_WAITACTIVE 0x5607
#define VT_DISALLOCATE 0x5608
struct vt_sizes {
  unsigned short v_rows;
  unsigned short v_cols;
  unsigned short v_scrollsize;
};
#define VT_RESIZE 0x5609
struct vt_consize {
  unsigned short v_rows;
  unsigned short v_cols;
  unsigned short v_vlin;
  unsigned short v_clin;
  unsigned short v_vcol;
  unsigned short v_ccol;
};
#define VT_RESIZEX 0x560A
#define VT_LOCKSWITCH 0x560B
#define VT_UNLOCKSWITCH 0x560C
#define VT_GETHIFONTMASK 0x560D
struct vt_event {
  unsigned int event;
#define VT_EVENT_SWITCH 0x0001
#define VT_EVENT_BLANK 0x0002
#define VT_EVENT_UNBLANK 0x0004
#define VT_EVENT_RESIZE 0x0008
#define VT_MAX_EVENT 0x000F
  unsigned int oldev;
  unsigned int newev;
  unsigned int pad[4];
};
#define VT_WAITEVENT 0x560E
struct vt_setactivate {
  unsigned int console;
  struct vt_mode mode;
};
#define VT_SETACTIVATE 0x560F
#endif