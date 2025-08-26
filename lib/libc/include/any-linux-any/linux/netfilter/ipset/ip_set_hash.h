/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef __IP_SET_HASH_H
#define __IP_SET_HASH_H

#include <linux/netfilter/ipset/ip_set.h>

/* Hash type specific error codes */
enum {
	/* Hash is full */
	IPSET_ERR_HASH_FULL = IPSET_ERR_TYPE_SPECIFIC,
	/* Null-valued element */
	IPSET_ERR_HASH_ELEM,
	/* Invalid protocol */
	IPSET_ERR_INVALID_PROTO,
	/* Protocol missing but must be specified */
	IPSET_ERR_MISSING_PROTO,
	/* Range not supported */
	IPSET_ERR_HASH_RANGE_UNSUPPORTED,
	/* Invalid range */
	IPSET_ERR_HASH_RANGE,
};


#endif /* __IP_SET_HASH_H */