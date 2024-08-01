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
#ifndef _NFNETLINK_COMPAT_H
#define _NFNETLINK_COMPAT_H
#include <linux/types.h>
#define NF_NETLINK_CONNTRACK_NEW 0x00000001
#define NF_NETLINK_CONNTRACK_UPDATE 0x00000002
#define NF_NETLINK_CONNTRACK_DESTROY 0x00000004
#define NF_NETLINK_CONNTRACK_EXP_NEW 0x00000008
#define NF_NETLINK_CONNTRACK_EXP_UPDATE 0x00000010
#define NF_NETLINK_CONNTRACK_EXP_DESTROY 0x00000020
struct nfattr {
  __u16 nfa_len;
  __u16 nfa_type;
};
#define NFNL_NFA_NEST 0x8000
#define NFA_TYPE(attr) ((attr)->nfa_type & 0x7fff)
#define NFA_ALIGNTO 4
#define NFA_ALIGN(len) (((len) + NFA_ALIGNTO - 1) & ~(NFA_ALIGNTO - 1))
#define NFA_OK(nfa,len) ((len) > 0 && (nfa)->nfa_len >= sizeof(struct nfattr) && (nfa)->nfa_len <= (len))
#define NFA_NEXT(nfa,attrlen) ((attrlen) -= NFA_ALIGN((nfa)->nfa_len), (struct nfattr *) (((char *) (nfa)) + NFA_ALIGN((nfa)->nfa_len)))
#define NFA_LENGTH(len) (NFA_ALIGN(sizeof(struct nfattr)) + (len))
#define NFA_SPACE(len) NFA_ALIGN(NFA_LENGTH(len))
#define NFA_DATA(nfa) ((void *) (((char *) (nfa)) + NFA_LENGTH(0)))
#define NFA_PAYLOAD(nfa) ((int) ((nfa)->nfa_len) - NFA_LENGTH(0))
#define NFA_NEST(skb,type) \
({ struct nfattr * __start = (struct nfattr *) skb_tail_pointer(skb); NFA_PUT(skb, (NFNL_NFA_NEST | type), 0, NULL); __start; })
#define NFA_NEST_END(skb,start) \
({ (start)->nfa_len = skb_tail_pointer(skb) - (unsigned char *) (start); (skb)->len; })
#define NFA_NEST_CANCEL(skb,start) \
({ if(start) skb_trim(skb, (unsigned char *) (start) - (skb)->data); - 1; })
#define NFM_NFA(n) ((struct nfattr *) (((char *) (n)) + NLMSG_ALIGN(sizeof(struct nfgenmsg))))
#define NFM_PAYLOAD(n) NLMSG_PAYLOAD(n, sizeof(struct nfgenmsg))
#endif