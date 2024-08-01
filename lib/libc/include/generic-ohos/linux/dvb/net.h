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
#ifndef _DVBNET_H_
#define _DVBNET_H_
#include <linux/types.h>
struct dvb_net_if {
  __u16 pid;
  __u16 if_num;
  __u8 feedtype;
#define DVB_NET_FEEDTYPE_MPE 0
#define DVB_NET_FEEDTYPE_ULE 1
};
#define NET_ADD_IF _IOWR('o', 52, struct dvb_net_if)
#define NET_REMOVE_IF _IO('o', 53)
#define NET_GET_IF _IOWR('o', 54, struct dvb_net_if)
struct __dvb_net_if_old {
  __u16 pid;
  __u16 if_num;
};
#define __NET_ADD_IF_OLD _IOWR('o', 52, struct __dvb_net_if_old)
#define __NET_GET_IF_OLD _IOWR('o', 54, struct __dvb_net_if_old)
#endif