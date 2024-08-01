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
#ifndef _LINUX_TIOCL_H
#define _LINUX_TIOCL_H
#define TIOCL_SETSEL 2
#define TIOCL_SELCHAR 0
#define TIOCL_SELWORD 1
#define TIOCL_SELLINE 2
#define TIOCL_SELPOINTER 3
#define TIOCL_SELCLEAR 4
#define TIOCL_SELMOUSEREPORT 16
#define TIOCL_SELBUTTONMASK 15
struct tiocl_selection {
  unsigned short xs;
  unsigned short ys;
  unsigned short xe;
  unsigned short ye;
  unsigned short sel_mode;
};
#define TIOCL_PASTESEL 3
#define TIOCL_UNBLANKSCREEN 4
#define TIOCL_SELLOADLUT 5
#define TIOCL_GETSHIFTSTATE 6
#define TIOCL_GETMOUSEREPORTING 7
#define TIOCL_SETVESABLANK 10
#define TIOCL_SETKMSGREDIRECT 11
#define TIOCL_GETFGCONSOLE 12
#define TIOCL_SCROLLCONSOLE 13
#define TIOCL_BLANKSCREEN 14
#define TIOCL_BLANKEDSCREEN 15
#define TIOCL_GETKMSGREDIRECT 17
#endif