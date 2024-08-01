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
#ifndef _LINUX_CAIF_SOCKET_H
#define _LINUX_CAIF_SOCKET_H
#include <linux/types.h>
#include <linux/socket.h>
enum caif_link_selector {
  CAIF_LINK_HIGH_BANDW,
  CAIF_LINK_LOW_LATENCY
};
enum caif_channel_priority {
  CAIF_PRIO_MIN = 0x01,
  CAIF_PRIO_LOW = 0x04,
  CAIF_PRIO_NORMAL = 0x0f,
  CAIF_PRIO_HIGH = 0x14,
  CAIF_PRIO_MAX = 0x1F
};
enum caif_protocol_type {
  CAIFPROTO_AT,
  CAIFPROTO_DATAGRAM,
  CAIFPROTO_DATAGRAM_LOOP,
  CAIFPROTO_UTIL,
  CAIFPROTO_RFM,
  CAIFPROTO_DEBUG,
  _CAIFPROTO_MAX
};
#define CAIFPROTO_MAX _CAIFPROTO_MAX
enum caif_at_type {
  CAIF_ATTYPE_PLAIN = 2
};
enum caif_debug_type {
  CAIF_DEBUG_TRACE_INTERACTIVE = 0,
  CAIF_DEBUG_TRACE,
  CAIF_DEBUG_INTERACTIVE,
};
enum caif_debug_service {
  CAIF_RADIO_DEBUG_SERVICE = 1,
  CAIF_APP_DEBUG_SERVICE
};
struct sockaddr_caif {
  __kernel_sa_family_t family;
  union {
    struct {
      __u8 type;
    } at;
    struct {
      char service[16];
    } util;
    union {
      __u32 connection_id;
      __u8 nsapi;
    } dgm;
    struct {
      __u32 connection_id;
      char volume[16];
    } rfm;
    struct {
      __u8 type;
      __u8 service;
    } dbg;
  } u;
};
enum caif_socket_opts {
  CAIFSO_LINK_SELECT = 127,
  CAIFSO_REQ_PARAM = 128,
  CAIFSO_RSP_PARAM = 129,
};
#endif