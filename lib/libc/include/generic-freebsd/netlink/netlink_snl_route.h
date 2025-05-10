/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2022 Alexander V. Chernikov <melifaro@FreeBSD.org>
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
#ifndef	_NETLINK_NETLINK_SNL_ROUTE_H_
#define	_NETLINK_NETLINK_SNL_ROUTE_H_

#include <netlink/netlink_snl.h>
#include <netlink/netlink_route.h>
#include <netinet/in.h>

/*
 * Simple Netlink Library - NETLINK_ROUTE helpers
 */

static inline struct sockaddr *
parse_rta_ip4(struct snl_state *ss, void *rta_data, int *perror)
{
	struct sockaddr_in *sin;

	sin = (struct sockaddr_in *)snl_allocz(ss, sizeof(struct sockaddr_in));
	if (sin == NULL) {
		*perror = ENOBUFS;
		return (NULL);
	}
	sin->sin_len = sizeof(struct sockaddr_in);
	sin->sin_family = AF_INET;
	memcpy(&sin->sin_addr, rta_data, sizeof(struct in_addr));
	return ((struct sockaddr *)sin);
}

static inline struct sockaddr *
parse_rta_ip6(struct snl_state *ss, void *rta_data, int *perror)
{
	struct sockaddr_in6 *sin6;

	sin6 = (struct sockaddr_in6 *)snl_allocz(ss, sizeof(struct sockaddr_in6));
	if (sin6 == NULL) {
		*perror = ENOBUFS;
		return (NULL);
	}
	sin6->sin6_len = sizeof(struct sockaddr_in6);
	sin6->sin6_family = AF_INET6;
	memcpy(&sin6->sin6_addr, rta_data, sizeof(struct in6_addr));
	return ((struct sockaddr *)sin6);
}

static inline struct sockaddr *
parse_rta_ip(struct snl_state *ss, struct rtattr *rta, int *perror)
{
	void *rta_data = NL_RTA_DATA(rta);
	int rta_len = NL_RTA_DATA_LEN(rta);

	if (rta_len == sizeof(struct in_addr)) {
		return (parse_rta_ip4(ss, rta_data, perror));
	} else if (rta_len == sizeof(struct in6_addr)) {
		return (parse_rta_ip6(ss, rta_data, perror));
	} else {
		*perror = ENOTSUP;
		return (NULL);
	}
	return (NULL);
}

static inline bool
snl_attr_get_ip(struct snl_state *ss, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	int error = 0;
	struct sockaddr *sa = parse_rta_ip(ss, (struct rtattr *)nla, &error);
	if (error == 0) {
		*((struct sockaddr **)target) = sa;
		return (true);
	}
	return (false);
}

static inline struct sockaddr *
parse_rta_via(struct snl_state *ss, struct rtattr *rta, int *perror)
{
	struct rtvia *via = (struct rtvia *)NL_RTA_DATA(rta);

	switch (via->rtvia_family) {
	case AF_INET:
		return (parse_rta_ip4(ss, via->rtvia_addr, perror));
	case AF_INET6:
		return (parse_rta_ip6(ss, via->rtvia_addr, perror));
	default:
		*perror = ENOTSUP;
		return (NULL);
	}
}

static inline bool
snl_attr_get_ipvia(struct snl_state *ss, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	int error = 0;

	struct sockaddr *sa = parse_rta_via(ss, (struct rtattr *)nla, &error);
	if (error == 0) {
		*((struct sockaddr **)target) = sa;
		return (true);
	}
	return (false);
}

static inline bool
snl_add_msg_attr_ip4(struct snl_writer *nw, int attrtype, const struct in_addr *addr)
{
	return (snl_add_msg_attr(nw, attrtype, 4, addr));
}

static inline bool
snl_add_msg_attr_ip6(struct snl_writer *nw, int attrtype, const struct in6_addr *addr)
{
	return (snl_add_msg_attr(nw, attrtype, 16, addr));
}

static inline bool
snl_add_msg_attr_ip(struct snl_writer *nw, int attrtype, const struct sockaddr *sa)
{
	const void *addr;

	switch (sa->sa_family) {
	case AF_INET:
		addr = &((const struct sockaddr_in *)(const void *)sa)->sin_addr;
		return (snl_add_msg_attr(nw, attrtype, 4, addr));
	case AF_INET6:
		addr = &((const struct sockaddr_in6 *)(const void *)sa)->sin6_addr;
		return (snl_add_msg_attr(nw, attrtype, 16, addr));
	}

	return (false);
}

static inline bool
snl_add_msg_attr_ipvia(struct snl_writer *nw, int attrtype, const struct sockaddr *sa)
{
	char buf[17];

	buf[0] = sa->sa_family;

	switch (sa->sa_family) {
	case AF_INET:
		memcpy(&buf[1], &((const struct sockaddr_in *)(const void *)sa)->sin_addr, 4);
		return (snl_add_msg_attr(nw, attrtype, 5, buf));
	case AF_INET6:
		memcpy(&buf[1], &((const struct sockaddr_in6 *)(const void *)sa)->sin6_addr, 16);
		return (snl_add_msg_attr(nw, attrtype, 17, buf));
	}

	return (false);
}

static inline bool
snl_attr_get_in_addr(struct snl_state *ss __unused, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	if (NLA_DATA_LEN(nla) != sizeof(struct in_addr))
		return (false);

	memcpy(target, NLA_DATA_CONST(nla), sizeof(struct in_addr));
	return (true);
}

static inline bool
snl_attr_get_in6_addr(struct snl_state *ss __unused, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	if (NLA_DATA_LEN(nla) != sizeof(struct in6_addr))
		return (false);

	memcpy(target, NLA_DATA_CONST(nla), sizeof(struct in6_addr));
	return (true);
}


#endif