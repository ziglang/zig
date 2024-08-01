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
#ifndef _ASM_TERMIOS_H
#define _ASM_TERMIOS_H
#include <linux/errno.h>
#include <asm/termbits.h>
#include <asm/ioctls.h>
struct sgttyb {
  char sg_ispeed;
  char sg_ospeed;
  char sg_erase;
  char sg_kill;
  int sg_flags;
};
struct tchars {
  char t_intrc;
  char t_quitc;
  char t_startc;
  char t_stopc;
  char t_eofc;
  char t_brkc;
};
struct ltchars {
  char t_suspc;
  char t_dsuspc;
  char t_rprntc;
  char t_flushc;
  char t_werasc;
  char t_lnextc;
};
struct winsize {
  unsigned short ws_row;
  unsigned short ws_col;
  unsigned short ws_xpixel;
  unsigned short ws_ypixel;
};
#define NCC 8
struct termio {
  unsigned short c_iflag;
  unsigned short c_oflag;
  unsigned short c_cflag;
  unsigned short c_lflag;
  char c_line;
  unsigned char c_cc[NCCS];
};
#define TIOCM_LE 0x001
#define TIOCM_DTR 0x002
#define TIOCM_RTS 0x004
#define TIOCM_ST 0x010
#define TIOCM_SR 0x020
#define TIOCM_CTS 0x040
#define TIOCM_CAR 0x100
#define TIOCM_CD TIOCM_CAR
#define TIOCM_RNG 0x200
#define TIOCM_RI TIOCM_RNG
#define TIOCM_DSR 0x400
#define TIOCM_OUT1 0x2000
#define TIOCM_OUT2 0x4000
#define TIOCM_LOOP 0x8000
#endif