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
#ifndef _UAPILINUX_ATM_TCP_H
#define _UAPILINUX_ATM_TCP_H
#include <linux/atmapi.h>
#include <linux/atm.h>
#include <linux/atmioc.h>
#include <linux/types.h>
struct atmtcp_hdr {
  __u16 vpi;
  __u16 vci;
  __u32 length;
};
#define ATMTCP_HDR_MAGIC (~0)
#define ATMTCP_CTRL_OPEN 1
#define ATMTCP_CTRL_CLOSE 2
struct atmtcp_control {
  struct atmtcp_hdr hdr;
  int type;
  atm_kptr_t vcc;
  struct sockaddr_atmpvc addr;
  struct atm_qos qos;
  int result;
} __ATM_API_ALIGN;
#define SIOCSIFATMTCP _IO('a', ATMIOC_ITF)
#define ATMTCP_CREATE _IO('a', ATMIOC_ITF + 14)
#define ATMTCP_REMOVE _IO('a', ATMIOC_ITF + 15)
#endif