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
#ifndef _LINUX_TIPC_CONFIG_H_
#define _LINUX_TIPC_CONFIG_H_
#include <linux/types.h>
#include <linux/string.h>
#include <linux/tipc.h>
#include <asm/byteorder.h>
#include <arpa/inet.h>
#define TIPC_CMD_NOOP 0x0000
#define TIPC_CMD_GET_NODES 0x0001
#define TIPC_CMD_GET_MEDIA_NAMES 0x0002
#define TIPC_CMD_GET_BEARER_NAMES 0x0003
#define TIPC_CMD_GET_LINKS 0x0004
#define TIPC_CMD_SHOW_NAME_TABLE 0x0005
#define TIPC_CMD_SHOW_PORTS 0x0006
#define TIPC_CMD_SHOW_LINK_STATS 0x000B
#define TIPC_CMD_SHOW_STATS 0x000F
#define TIPC_CMD_GET_REMOTE_MNG 0x4003
#define TIPC_CMD_GET_MAX_PORTS 0x4004
#define TIPC_CMD_GET_MAX_PUBL 0x4005
#define TIPC_CMD_GET_MAX_SUBSCR 0x4006
#define TIPC_CMD_GET_MAX_ZONES 0x4007
#define TIPC_CMD_GET_MAX_CLUSTERS 0x4008
#define TIPC_CMD_GET_MAX_NODES 0x4009
#define TIPC_CMD_GET_MAX_SLAVES 0x400A
#define TIPC_CMD_GET_NETID 0x400B
#define TIPC_CMD_ENABLE_BEARER 0x4101
#define TIPC_CMD_DISABLE_BEARER 0x4102
#define TIPC_CMD_SET_LINK_TOL 0x4107
#define TIPC_CMD_SET_LINK_PRI 0x4108
#define TIPC_CMD_SET_LINK_WINDOW 0x4109
#define TIPC_CMD_SET_LOG_SIZE 0x410A
#define TIPC_CMD_DUMP_LOG 0x410B
#define TIPC_CMD_RESET_LINK_STATS 0x410C
#define TIPC_CMD_SET_NODE_ADDR 0x8001
#define TIPC_CMD_SET_REMOTE_MNG 0x8003
#define TIPC_CMD_SET_MAX_PORTS 0x8004
#define TIPC_CMD_SET_MAX_PUBL 0x8005
#define TIPC_CMD_SET_MAX_SUBSCR 0x8006
#define TIPC_CMD_SET_MAX_ZONES 0x8007
#define TIPC_CMD_SET_MAX_CLUSTERS 0x8008
#define TIPC_CMD_SET_MAX_NODES 0x8009
#define TIPC_CMD_SET_MAX_SLAVES 0x800A
#define TIPC_CMD_SET_NETID 0x800B
#define TIPC_CMD_NOT_NET_ADMIN 0xC001
#define TIPC_TLV_NONE 0
#define TIPC_TLV_VOID 1
#define TIPC_TLV_UNSIGNED 2
#define TIPC_TLV_STRING 3
#define TIPC_TLV_LARGE_STRING 4
#define TIPC_TLV_ULTRA_STRING 5
#define TIPC_TLV_ERROR_STRING 16
#define TIPC_TLV_NET_ADDR 17
#define TIPC_TLV_MEDIA_NAME 18
#define TIPC_TLV_BEARER_NAME 19
#define TIPC_TLV_LINK_NAME 20
#define TIPC_TLV_NODE_INFO 21
#define TIPC_TLV_LINK_INFO 22
#define TIPC_TLV_BEARER_CONFIG 23
#define TIPC_TLV_LINK_CONFIG 24
#define TIPC_TLV_NAME_TBL_QUERY 25
#define TIPC_TLV_PORT_REF 26
#define TIPC_MIN_LINK_PRI 0
#define TIPC_DEF_LINK_PRI 10
#define TIPC_MAX_LINK_PRI 31
#define TIPC_MEDIA_LINK_PRI (TIPC_MAX_LINK_PRI + 1)
#define TIPC_MIN_LINK_TOL 50
#define TIPC_DEF_LINK_TOL 1500
#define TIPC_MAX_LINK_TOL 30000
#if TIPC_MIN_LINK_TOL < 16
#error "TIPC_MIN_LINK_TOL is too small (abort limit may be NaN)"
#endif
#define TIPC_MIN_LINK_WIN 16
#define TIPC_DEF_LINK_WIN 50
#define TIPC_MAX_LINK_WIN 8191
#define TIPC_DEF_LINK_UDP_MTU 14000
struct tipc_node_info {
  __be32 addr;
  __be32 up;
};
struct tipc_link_info {
  __be32 dest;
  __be32 up;
  char str[TIPC_MAX_LINK_NAME];
};
struct tipc_bearer_config {
  __be32 priority;
  __be32 disc_domain;
  char name[TIPC_MAX_BEARER_NAME];
};
struct tipc_link_config {
  __be32 value;
  char name[TIPC_MAX_LINK_NAME];
};
#define TIPC_NTQ_ALLTYPES 0x80000000
struct tipc_name_table_query {
  __be32 depth;
  __be32 type;
  __be32 lowbound;
  __be32 upbound;
};
#define TIPC_CFG_TLV_ERROR "\x80"
#define TIPC_CFG_NOT_NET_ADMIN "\x81"
#define TIPC_CFG_NOT_ZONE_MSTR "\x82"
#define TIPC_CFG_NO_REMOTE "\x83"
#define TIPC_CFG_NOT_SUPPORTED "\x84"
#define TIPC_CFG_INVALID_VALUE "\x85"
struct tlv_desc {
  __be16 tlv_len;
  __be16 tlv_type;
};
#define TLV_ALIGNTO 4
#define TLV_ALIGN(datalen) (((datalen) + (TLV_ALIGNTO - 1)) & ~(TLV_ALIGNTO - 1))
#define TLV_LENGTH(datalen) (sizeof(struct tlv_desc) + (datalen))
#define TLV_SPACE(datalen) (TLV_ALIGN(TLV_LENGTH(datalen)))
#define TLV_DATA(tlv) ((void *) ((char *) (tlv) + TLV_LENGTH(0)))
struct tlv_list_desc {
  struct tlv_desc * tlv_ptr;
  __u32 tlv_space;
};
#define TIPC_GENL_NAME "TIPC"
#define TIPC_GENL_VERSION 0x1
#define TIPC_GENL_CMD 0x1
struct tipc_genlmsghdr {
  __u32 dest;
  __u16 cmd;
  __u16 reserved;
};
#define TIPC_GENL_HDRLEN NLMSG_ALIGN(sizeof(struct tipc_genlmsghdr))
struct tipc_cfg_msg_hdr {
  __be32 tcm_len;
  __be16 tcm_type;
  __be16 tcm_flags;
  char tcm_reserved[8];
};
#define TCM_F_REQUEST 0x1
#define TCM_F_MORE 0x2
#define TCM_ALIGN(datalen) (((datalen) + 3) & ~3)
#define TCM_LENGTH(datalen) (sizeof(struct tipc_cfg_msg_hdr) + datalen)
#define TCM_SPACE(datalen) (TCM_ALIGN(TCM_LENGTH(datalen)))
#define TCM_DATA(tcm_hdr) ((void *) ((char *) (tcm_hdr) + TCM_LENGTH(0)))
#endif