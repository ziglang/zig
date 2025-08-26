/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _NETFILTER_NF_NAT_H
#define _NETFILTER_NF_NAT_H

#include <linux/netfilter.h>
#include <linux/netfilter/nf_conntrack_tuple_common.h>

#define NF_NAT_RANGE_MAP_IPS			(1 << 0)
#define NF_NAT_RANGE_PROTO_SPECIFIED		(1 << 1)
#define NF_NAT_RANGE_PROTO_RANDOM		(1 << 2)
#define NF_NAT_RANGE_PERSISTENT			(1 << 3)
#define NF_NAT_RANGE_PROTO_RANDOM_FULLY		(1 << 4)
#define NF_NAT_RANGE_PROTO_OFFSET		(1 << 5)
#define NF_NAT_RANGE_NETMAP			(1 << 6)

#define NF_NAT_RANGE_PROTO_RANDOM_ALL		\
	(NF_NAT_RANGE_PROTO_RANDOM | NF_NAT_RANGE_PROTO_RANDOM_FULLY)

#define NF_NAT_RANGE_MASK					\
	(NF_NAT_RANGE_MAP_IPS | NF_NAT_RANGE_PROTO_SPECIFIED |	\
	 NF_NAT_RANGE_PROTO_RANDOM | NF_NAT_RANGE_PERSISTENT |	\
	 NF_NAT_RANGE_PROTO_RANDOM_FULLY | NF_NAT_RANGE_PROTO_OFFSET | \
	 NF_NAT_RANGE_NETMAP)

struct nf_nat_ipv4_range {
	unsigned int			flags;
	__be32				min_ip;
	__be32				max_ip;
	union nf_conntrack_man_proto	min;
	union nf_conntrack_man_proto	max;
};

struct nf_nat_ipv4_multi_range_compat {
	unsigned int			rangesize;
	struct nf_nat_ipv4_range	range[1];
};

struct nf_nat_range {
	unsigned int			flags;
	union nf_inet_addr		min_addr;
	union nf_inet_addr		max_addr;
	union nf_conntrack_man_proto	min_proto;
	union nf_conntrack_man_proto	max_proto;
};

struct nf_nat_range2 {
	unsigned int			flags;
	union nf_inet_addr		min_addr;
	union nf_inet_addr		max_addr;
	union nf_conntrack_man_proto	min_proto;
	union nf_conntrack_man_proto	max_proto;
	union nf_conntrack_man_proto	base_proto;
};

#endif /* _NETFILTER_NF_NAT_H */