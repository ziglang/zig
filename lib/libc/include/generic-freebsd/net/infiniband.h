/*-
 * Copyright (c) 2020 Mellanox Technologies. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS `AS IS' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef __INFINIBAND_H__
#define	__INFINIBAND_H__

#include <sys/cdefs.h>
#include <sys/stdint.h>

#define	INFINIBAND_ADDR_LEN	20	/* bytes */
#define	INFINIBAND_MTU		1500	/* bytes - default value */

#define	INFINIBAND_ENC_LEN	4	/* bytes */
#define	INFINIBAND_HDR_LEN \
    (INFINIBAND_ADDR_LEN + INFINIBAND_ENC_LEN)

#define	INFINIBAND_IS_MULTICAST(addr) \
    ((addr)[4] == 0xff)

struct infiniband_header {
	uint8_t	ib_hwaddr[INFINIBAND_ADDR_LEN];
	uint16_t ib_protocol;		/* big endian */
	uint16_t ib_reserved;		/* zero */
} __packed;

struct infiniband_address {
	uint8_t	octet[INFINIBAND_ADDR_LEN];
} __packed;

#ifdef _KERNEL

#include <sys/_eventhandler.h>

struct ifnet;
struct mbuf;

extern void infiniband_ifattach(struct ifnet *, const uint8_t *hwaddr, const uint8_t *bcaddr);
extern void infiniband_ifdetach(struct ifnet *);
extern void infiniband_bpf_mtap(struct ifnet *, struct mbuf *);

/* new infiniband interface attached event */
typedef void (*infiniband_ifattach_event_handler_t)(void *, struct ifnet *);

EVENTHANDLER_DECLARE(infiniband_ifattach_event, infiniband_ifattach_event_handler_t);

#endif

#endif					/* __INFINIBAND_H__ */