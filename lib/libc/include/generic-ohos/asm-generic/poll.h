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
#ifndef __ASM_GENERIC_POLL_H
#define __ASM_GENERIC_POLL_H
#define POLLIN 0x0001
#define POLLPRI 0x0002
#define POLLOUT 0x0004
#define POLLERR 0x0008
#define POLLHUP 0x0010
#define POLLNVAL 0x0020
#define POLLRDNORM 0x0040
#define POLLRDBAND 0x0080
#ifndef POLLWRNORM
#define POLLWRNORM 0x0100
#endif
#ifndef POLLWRBAND
#define POLLWRBAND 0x0200
#endif
#ifndef POLLMSG
#define POLLMSG 0x0400
#endif
#ifndef POLLREMOVE
#define POLLREMOVE 0x1000
#endif
#ifndef POLLRDHUP
#define POLLRDHUP 0x2000
#endif
#define POLLFREE (__force __poll_t) 0x4000
#define POLL_BUSY_LOOP (__force __poll_t) 0x8000
struct pollfd {
  int fd;
  short events;
  short revents;
};
#endif