/*-
 * Copyright (c) 2015
 * 	Alexander V. Chernikov <melifaro@FreeBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NETINET_IN_FIB_H_
#define	_NETINET_IN_FIB_H_

struct route_in {
	/* common fields shared among all 'struct route' */
	struct nhop_object *ro_nh;
	struct	llentry *ro_lle;
	char		*ro_prepend;
	uint16_t	ro_plen;
	uint16_t	ro_flags;
	uint16_t	ro_mtu;	/* saved ro_rt mtu */
	uint16_t	spare;
	/* custom sockaddr */
	struct sockaddr_in ro_dst4;
};

struct rtentry;
struct route_nhop_data;

struct nhop_object *fib4_lookup(uint32_t fibnum, struct in_addr dst,
    uint32_t scopeid, uint32_t flags, uint32_t flowid);
int fib4_check_urpf(uint32_t fibnum, struct in_addr dst, uint32_t scopeid,
    uint32_t flags, const struct ifnet *src_if);
struct rtentry *fib4_lookup_rt(uint32_t fibnum, struct in_addr dst, uint32_t scopeid,
    uint32_t flags, struct route_nhop_data *nrd);
struct nhop_object *fib4_lookup_debugnet(uint32_t fibnum, struct in_addr dst,
    uint32_t scopeid, uint32_t flags);
uint32_t fib4_calc_software_hash(struct in_addr src, struct in_addr dst,
    unsigned short src_port, unsigned short dst_port, char proto,
    uint32_t *phashtype);
#endif