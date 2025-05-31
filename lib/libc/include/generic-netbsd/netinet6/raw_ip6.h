/*	$NetBSD: raw_ip6.h,v 1.5 2018/08/22 01:05:24 msaitoh Exp $	*/
/*	$KAME: raw_ip6.h,v 1.2 2001/05/27 13:28:35 itojun Exp $	*/

/*
 * Copyright (C) 2001 WIDE Project.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NETINET6_RAW_IP6_H_
#define _NETINET6_RAW_IP6_H_

/*
 * ICMPv6 stat is counted separately.  see netinet/icmp6.h
 */
#define	RIP6_STAT_IPACKETS	0	/* total input packets */
#define	RIP6_STAT_ISUM		1	/* input checksum computations */
#define	RIP6_STAT_BADSUM	2	/* of above, checksum error */
#define	RIP6_STAT_NOSOCK	3	/* no matching socket */
#define	RIP6_STAT_NOSOCKMCAST	4	/* of above, arrived as multicast */
#define	RIP6_STAT_FULLSOCK	5	/* not delivered, input socket full */
#define	RIP6_STAT_OPACKETS	6	/* total output packets */

#define	RIP6_NSTATS		7

/*
 * Names for Raw IPv6 sysctl objects
 */
#define RAW6CTL_STATS	1

#ifdef _KERNEL
extern struct rip6stat rip6stat;
#endif

#endif /* !_NETINET6_RAW_IP6_H_ */