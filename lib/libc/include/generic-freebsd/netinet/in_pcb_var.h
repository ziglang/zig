/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1990, 1993
 *	The Regents of the University of California.
 * Copyright (c) 2010-2011 Juniper Networks, Inc.
 * All rights reserved.
 *
 * Portions of this software were developed by Robert N. M. Watson under
 * contract to Juniper Networks, Inc.
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
 *
 *	@(#)in_pcb.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET_IN_PCB_VAR_H_
#define _NETINET_IN_PCB_VAR_H_

/*
 * Definitions shared between netinet/in_pcb.c and netinet6/in6_pcb.c
 */

VNET_DECLARE(uint32_t, in_pcbhashseed);
#define	V_in_pcbhashseed	VNET(in_pcbhashseed)

void	inp_lock(struct inpcb *inp, const inp_lookup_t lock);
void	inp_unlock(struct inpcb *inp, const inp_lookup_t lock);
int	inp_trylock(struct inpcb *inp, const inp_lookup_t lock);
bool	inp_smr_lock(struct inpcb *, const inp_lookup_t);
int	in_pcb_lport(struct inpcb *, struct in_addr *, u_short *,
	    struct ucred *, int);
int	in_pcb_lport_dest(struct inpcb *inp, struct sockaddr *lsa,
            u_short *lportp, struct sockaddr *fsa, u_short fport,
            struct ucred *cred, int lookupflags);
struct inpcb *	in_pcblookup_local(struct inpcbinfo *, struct in_addr, u_short,
	    int, struct ucred *);

struct inpcbport {
	struct inpcbhead phd_pcblist;
	CK_LIST_ENTRY(inpcbport) phd_hash;
	u_short phd_port;
};

#endif /* !_NETINET_IN_PCB_VAR_H_ */