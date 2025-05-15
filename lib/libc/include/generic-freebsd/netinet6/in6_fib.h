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

#ifndef _NETINET6_IN6_FIB_H_
#define	_NETINET6_IN6_FIB_H_

struct rtentry;
struct route_nhop_data;

struct nhop_object *fib6_lookup(uint32_t fibnum,
    const struct in6_addr *dst6, uint32_t scopeid, uint32_t flags,
    uint32_t flowid);
int fib6_check_urpf(uint32_t fibnum, const struct in6_addr *dst6,
    uint32_t scopeid, uint32_t flags, const struct ifnet *src_if);
struct rtentry *fib6_lookup_rt(uint32_t fibnum, const struct in6_addr *dst6,
    uint32_t scopeid, uint32_t flags, struct route_nhop_data *rnd);
struct nhop_object *fib6_lookup_debugnet(uint32_t fibnum,
    const struct in6_addr *dst6, uint32_t scopeid, uint32_t flags);
struct nhop_object *fib6_radix_lookup_nh(uint32_t fibnum,
    const struct in6_addr *dst6, uint32_t scopeid);
uint32_t fib6_calc_software_hash(const struct in6_addr *src,
    const struct in6_addr *dst, unsigned short src_port, unsigned short dst_port,
    char proto, uint32_t *phashtype);
#endif