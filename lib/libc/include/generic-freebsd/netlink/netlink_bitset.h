/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2023 Alexander V. Chernikov <melifaro@FreeBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * Generic netlink message header and attributes
 */
#ifndef _NETLINK_NETLINK_BITSET_H_
#define	_NETLINK_NETLINK_BITSET_H_

#include <netlink/netlink.h>

/* Bitset type nested attributes */
enum {
	NLA_BITSET_UNSPEC,
	NLA_BITSET_NOMASK	= 1, /* flag: mask of valid bits not provided */
	NLA_BITSET_SIZE		= 2, /* u32: max valid bit # */
	NLA_BITSET_BITS		= 3, /* nested: array of NLA_BITSET_BIT */
	NLA_BITSET_VALUE	= 4, /* binary: array of bit values */
	NLA_BITSET_MASK		= 5, /* binary: array of valid bits */
	__NLA_BITSET_MAX,
};
#define	NLA_BITSET_MAX	(__NLA_BITSET_MAX - 1)

enum {
	NLA_BITSET_BIT_UNSPEC,
	NLA_BITSET_BIT_INDEX	= 1, /* u32: index of the bit */
	NLA_BITSET_BIT_NAME	= 2, /* string: bit description */
	NLA_BITSET_BIT_VALUE	= 3, /* flag: provided if bit is set */
	__NLA_BITSET_BIT_MAX,
};
#define	NLA_BITSET_BIT_MAX	(__NLA_BITSET_BIT_MAX - 1)

#endif