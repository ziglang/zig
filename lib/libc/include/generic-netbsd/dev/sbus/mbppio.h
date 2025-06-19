/*	$NetBSD: mbppio.h,v 1.2 2008/07/02 10:16:20 plunky Exp $	*/

/*-
 * Copyright (c) 1998 Iain Hibbert
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <sys/ioctl.h>

struct mbpp_param {
	int	bp_burst;	/* chars to send/recv in one call */
	int	bp_timeout;	/* timeout: -1 blocking, 0 non blocking >0 ms */
	int	bp_delay;	/* delay between polls (ms) */
};

#define MBPP_BLOCK	-1
#define MBPP_NOBLOCK	0

/* defaults */
#define MBPP_BURST	1024
#define MBPP_TIMEOUT	MBPP_BLOCK
#define MBPP_DELAY	10

/* limits */
#define MBPP_BURST_MIN	1
#define MBPP_BURST_MAX	1024
#define MBPP_DELAY_MIN	0
#define MBPP_DELAY_MAX	30000

/* status bits */
#define MBPP_BUSY	(1<<0)
#define MBPP_PAPER	(1<<1)

/* ioctl commands */
#define MBPPIOCSPARAM	_IOW('P', 0x1, struct mbpp_param)
#define MBPPIOCGPARAM	_IOR('P', 0x2, struct mbpp_param)
#define MBPPIOCGSTAT	_IOR('P', 0x4, int)