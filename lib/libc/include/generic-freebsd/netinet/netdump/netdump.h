/*-
 * Copyright (c) 2005-2014 Sandvine Incorporated
 * Copyright (c) 2000 Darrell Anderson <anderson@cs.duke.edu>
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NETINET_NETDUMP_H_
#define	_NETINET_NETDUMP_H_

#include <sys/types.h>
#include <sys/disk.h>
#include <sys/ioccom.h>

#include <net/if.h>
#include <netinet/in.h>

/* Netdump wire protocol definitions are consumed by the ftp/netdumpd port. */
#define	NETDUMP_PORT		20023	/* Server UDP port for heralds. */
#define	NETDUMP_ACKPORT		20024	/* Client UDP port for acks. */

#define	NETDUMP_HERALD		DEBUGNET_HERALD
#define	NETDUMP_FINISHED	DEBUGNET_FINISHED
#define	NETDUMP_VMCORE		DEBUGNET_DATA
#define	NETDUMP_KDH		4	/* Contains kernel dump header. */
#define	NETDUMP_EKCD_KEY	5	/* Contains kernel dump key. */

#define	NETDUMP_DATASIZE	4096	/* Arbitrary packet size limit. */

/* For netdumpd. */
#ifndef _KERNEL
#define	netdump_msg_hdr	debugnet_msg_hdr
#define	mh__pad		mh_aux2
#define	netdump_ack	debugnet_ack
#define	na_seqno	da_seqno
#endif /* !_KERNEL */

#define	_PATH_NETDUMP	"/dev/netdump"

#endif /* _NETINET_NETDUMP_H_ */