/*	$NetBSD: mpls.h,v 1.2 2016/10/08 20:19:37 joerg Exp $ */

/*-
 * Copyright (c) 2010 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Mihai Chelaru <kefren@NetBSD.org>
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _NETMPLS_MPLS_H_
#define _NETMPLS_MPLS_H_

#include <sys/param.h>
#include <sys/time.h>
#include <sys/proc.h>
#include <sys/queue.h>

#include <net/if.h>
#include <net/if_dl.h>

#define MPLS_LABEL_IPV4NULL	0	/* IPv4 Explicit NULL Label	*/
#define MPLS_LABEL_RTALERT	1	/* Router Alert Label		*/
#define MPLS_LABEL_IPV6NULL	2	/* IPv6 Explicit NULL Label	*/
#define MPLS_LABEL_IMPLNULL	3	/* Implicit NULL Label		*/
#define MPLS_LABEL_RESMAX	15	/* Maximum reserved Label	*/

union mpls_shim {
	uint32_t s_addr;		/* the whole shim */
	struct {
#if BYTE_ORDER == LITTLE_ENDIAN
		uint32_t ttl:8;
		uint32_t bos:1;
		uint32_t exp:3;
		uint32_t label:20;
#else
		uint32_t label:20;
		uint32_t exp:3;
		uint32_t bos:1;
		uint32_t ttl:8;
#endif
	} shim;
};

struct sockaddr_mpls {
	uint8_t smpls_len;
	uint8_t smpls_family;
	uint8_t smpls_pad[2];
	union mpls_shim smpls_addr;
};
__CTASSERT(sizeof(struct sockaddr_mpls) == 8);

#endif /* !_NETMPLS_MPLS_H_ */