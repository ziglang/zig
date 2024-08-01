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
#ifndef _UAPI__LINUX_NETLINK_H
#define _UAPI__LINUX_NETLINK_H
#include <linux/kernel.h>
#include <linux/socket.h>
#include <linux/types.h>
#define NETLINK_ROUTE 0
#define NETLINK_UNUSED 1
#define NETLINK_USERSOCK 2
#define NETLINK_FIREWALL 3
#define NETLINK_SOCK_DIAG 4
#define NETLINK_NFLOG 5
#define NETLINK_XFRM 6
#define NETLINK_SELINUX 7
#define NETLINK_ISCSI 8
#define NETLINK_AUDIT 9
#define NETLINK_FIB_LOOKUP 10
#define NETLINK_CONNECTOR 11
#define NETLINK_NETFILTER 12
#define NETLINK_IP6_FW 13
#define NETLINK_DNRTMSG 14
#define NETLINK_KOBJECT_UEVENT 15
#define NETLINK_GENERIC 16
#define NETLINK_SCSITRANSPORT 18
#define NETLINK_ECRYPTFS 19
#define NETLINK_RDMA 20
#define NETLINK_CRYPTO 21
#define NETLINK_SMC 22
#define NETLINK_INET_DIAG NETLINK_SOCK_DIAG
#define MAX_LINKS 32
struct sockaddr_nl {
  __kernel_sa_family_t nl_family;
  unsigned short nl_pad;
  __u32 nl_pid;
  __u32 nl_groups;
};
struct nlmsghdr {
  __u32 nlmsg_len;
  __u16 nlmsg_type;
  __u16 nlmsg_flags;
  __u32 nlmsg_seq;
  __u32 nlmsg_pid;
};
#define NLM_F_REQUEST 0x01
#define NLM_F_MULTI 0x02
#define NLM_F_ACK 0x04
#define NLM_F_ECHO 0x08
#define NLM_F_DUMP_INTR 0x10
#define NLM_F_DUMP_FILTERED 0x20
#define NLM_F_ROOT 0x100
#define NLM_F_MATCH 0x200
#define NLM_F_ATOMIC 0x400
#define NLM_F_DUMP (NLM_F_ROOT | NLM_F_MATCH)
#define NLM_F_REPLACE 0x100
#define NLM_F_EXCL 0x200
#define NLM_F_CREATE 0x400
#define NLM_F_APPEND 0x800
#define NLM_F_NONREC 0x100
#define NLM_F_CAPPED 0x100
#define NLM_F_ACK_TLVS 0x200
#define NLMSG_ALIGNTO 4U
#define NLMSG_ALIGN(len) (((len) + NLMSG_ALIGNTO - 1) & ~(NLMSG_ALIGNTO - 1))
#define NLMSG_HDRLEN ((int) NLMSG_ALIGN(sizeof(struct nlmsghdr)))
#define NLMSG_LENGTH(len) ((len) + NLMSG_HDRLEN)
#define NLMSG_SPACE(len) NLMSG_ALIGN(NLMSG_LENGTH(len))
#define NLMSG_DATA(nlh) ((void *) (((char *) nlh) + NLMSG_LENGTH(0)))
#define NLMSG_NEXT(nlh,len) ((len) -= NLMSG_ALIGN((nlh)->nlmsg_len), (struct nlmsghdr *) (((char *) (nlh)) + NLMSG_ALIGN((nlh)->nlmsg_len)))
#define NLMSG_OK(nlh,len) ((len) >= (int) sizeof(struct nlmsghdr) && (nlh)->nlmsg_len >= sizeof(struct nlmsghdr) && (nlh)->nlmsg_len <= (len))
#define NLMSG_PAYLOAD(nlh,len) ((nlh)->nlmsg_len - NLMSG_SPACE((len)))
#define NLMSG_NOOP 0x1
#define NLMSG_ERROR 0x2
#define NLMSG_DONE 0x3
#define NLMSG_OVERRUN 0x4
#define NLMSG_MIN_TYPE 0x10
struct nlmsgerr {
  int error;
  struct nlmsghdr msg;
};
enum nlmsgerr_attrs {
  NLMSGERR_ATTR_UNUSED,
  NLMSGERR_ATTR_MSG,
  NLMSGERR_ATTR_OFFS,
  NLMSGERR_ATTR_COOKIE,
  NLMSGERR_ATTR_POLICY,
  __NLMSGERR_ATTR_MAX,
  NLMSGERR_ATTR_MAX = __NLMSGERR_ATTR_MAX - 1
};
#define NETLINK_ADD_MEMBERSHIP 1
#define NETLINK_DROP_MEMBERSHIP 2
#define NETLINK_PKTINFO 3
#define NETLINK_BROADCAST_ERROR 4
#define NETLINK_NO_ENOBUFS 5
#define NETLINK_RX_RING 6
#define NETLINK_TX_RING 7
#define NETLINK_LISTEN_ALL_NSID 8
#define NETLINK_LIST_MEMBERSHIPS 9
#define NETLINK_CAP_ACK 10
#define NETLINK_EXT_ACK 11
#define NETLINK_GET_STRICT_CHK 12
struct nl_pktinfo {
  __u32 group;
};
struct nl_mmap_req {
  unsigned int nm_block_size;
  unsigned int nm_block_nr;
  unsigned int nm_frame_size;
  unsigned int nm_frame_nr;
};
struct nl_mmap_hdr {
  unsigned int nm_status;
  unsigned int nm_len;
  __u32 nm_group;
  __u32 nm_pid;
  __u32 nm_uid;
  __u32 nm_gid;
};
enum nl_mmap_status {
  NL_MMAP_STATUS_UNUSED,
  NL_MMAP_STATUS_RESERVED,
  NL_MMAP_STATUS_VALID,
  NL_MMAP_STATUS_COPY,
  NL_MMAP_STATUS_SKIP,
};
#define NL_MMAP_MSG_ALIGNMENT NLMSG_ALIGNTO
#define NL_MMAP_MSG_ALIGN(sz) __ALIGN_KERNEL(sz, NL_MMAP_MSG_ALIGNMENT)
#define NL_MMAP_HDRLEN NL_MMAP_MSG_ALIGN(sizeof(struct nl_mmap_hdr))
#define NET_MAJOR 36
enum {
  NETLINK_UNCONNECTED = 0,
  NETLINK_CONNECTED,
};
struct nlattr {
  __u16 nla_len;
  __u16 nla_type;
};
#define NLA_F_NESTED (1 << 15)
#define NLA_F_NET_BYTEORDER (1 << 14)
#define NLA_TYPE_MASK ~(NLA_F_NESTED | NLA_F_NET_BYTEORDER)
#define NLA_ALIGNTO 4
#define NLA_ALIGN(len) (((len) + NLA_ALIGNTO - 1) & ~(NLA_ALIGNTO - 1))
#define NLA_HDRLEN ((int) NLA_ALIGN(sizeof(struct nlattr)))
struct nla_bitfield32 {
  __u32 value;
  __u32 selector;
};
enum netlink_attribute_type {
  NL_ATTR_TYPE_INVALID,
  NL_ATTR_TYPE_FLAG,
  NL_ATTR_TYPE_U8,
  NL_ATTR_TYPE_U16,
  NL_ATTR_TYPE_U32,
  NL_ATTR_TYPE_U64,
  NL_ATTR_TYPE_S8,
  NL_ATTR_TYPE_S16,
  NL_ATTR_TYPE_S32,
  NL_ATTR_TYPE_S64,
  NL_ATTR_TYPE_BINARY,
  NL_ATTR_TYPE_STRING,
  NL_ATTR_TYPE_NUL_STRING,
  NL_ATTR_TYPE_NESTED,
  NL_ATTR_TYPE_NESTED_ARRAY,
  NL_ATTR_TYPE_BITFIELD32,
};
enum netlink_policy_type_attr {
  NL_POLICY_TYPE_ATTR_UNSPEC,
  NL_POLICY_TYPE_ATTR_TYPE,
  NL_POLICY_TYPE_ATTR_MIN_VALUE_S,
  NL_POLICY_TYPE_ATTR_MAX_VALUE_S,
  NL_POLICY_TYPE_ATTR_MIN_VALUE_U,
  NL_POLICY_TYPE_ATTR_MAX_VALUE_U,
  NL_POLICY_TYPE_ATTR_MIN_LENGTH,
  NL_POLICY_TYPE_ATTR_MAX_LENGTH,
  NL_POLICY_TYPE_ATTR_POLICY_IDX,
  NL_POLICY_TYPE_ATTR_POLICY_MAXTYPE,
  NL_POLICY_TYPE_ATTR_BITFIELD32_MASK,
  NL_POLICY_TYPE_ATTR_PAD,
  NL_POLICY_TYPE_ATTR_MASK,
  __NL_POLICY_TYPE_ATTR_MAX,
  NL_POLICY_TYPE_ATTR_MAX = __NL_POLICY_TYPE_ATTR_MAX - 1
};
#endif