/*	$NetBSD: dmover_io.h,v 1.4 2017/10/28 06:27:32 riastradh Exp $	*/

/*
 * Copyright (c) 2002, 2003 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Jason R. Thorpe for Wasabi Systems, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed for the NetBSD Project by
 *	Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _DMOVER_DMOVER_IO_H_
#define _DMOVER_DMOVER_IO_H_

#include <sys/types.h>
#include <sys/ioccom.h>
#include <sys/uio.h>

typedef struct {
	struct iovec *dmbuf_iov;
	u_int dmbuf_iovcnt;
} dmio_buffer;

/*
 * dmio_usrreq:
 *
 *	Request structure passed from user-space.
 */
struct dmio_usrreq {
	/* Output buffer. */
	dmio_buffer req_outbuf;

	/*
	 * General purpose immediate value.  Can be used as an
	 * input, output, or both, depending on the function.
	 * The output is transmitted via the usrresp structure.
	 */
	uint8_t req_immediate[8];

	/* Input buffer. */
	dmio_buffer *req_inbuf;

	uint32_t req_id;	/* request ID; passed in response */
};

/*
 * dmio_usrresp:
 *
 *	Response structure passed to user-space.
 */
struct dmio_usrresp {
	uint32_t resp_id;	/* request ID */
	int resp_error;		/* error, 0 if success */
	uint8_t resp_immediate[8];
};

/*
 * DMIO_SETFUNC:
 *
 *	Ioctl to set the function type for the session.
 */
#define	DMIO_SETFUNC		 _IOW('D', 0, struct dmio_setfunc)

#define	DMIO_MAX_FUNCNAME	64
struct dmio_setfunc {
	char dsf_name[DMIO_MAX_FUNCNAME];
};

#endif /* _DMOVER_DMOVER_IO_H_ */