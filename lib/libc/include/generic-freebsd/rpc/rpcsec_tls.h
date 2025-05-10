/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 Rick Macklem
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

#ifndef	_RPC_RPCSEC_TLS_H_
#define	_RPC_RPCSEC_TLS_H_

/* Operation values for rpctls syscall. */
#define	RPCTLS_SYSC_CLSETPATH	1
#define	RPCTLS_SYSC_CLSOCKET	2
#define	RPCTLS_SYSC_CLSHUTDOWN	3
#define	RPCTLS_SYSC_SRVSETPATH	4
#define	RPCTLS_SYSC_SRVSOCKET	5
#define	RPCTLS_SYSC_SRVSHUTDOWN	6
#define	RPCTLS_SYSC_SRVSTARTUP	7

/* Max nprocs for SRV startup */
#define	RPCTLS_SRV_MAXNPROCS	16

/* System call used by the rpctlscd, rpctlssd daemons. */
int	rpctls_syscall(int, const char *);

/* Flag bits to indicate certificate results. */
#define	RPCTLS_FLAGS_HANDSHAKE	0x01
#define	RPCTLS_FLAGS_GOTCERT	0x02
#define	RPCTLS_FLAGS_SELFSIGNED	0x04
#define	RPCTLS_FLAGS_VERIFIED	0x08
#define	RPCTLS_FLAGS_DISABLED	0x10
#define	RPCTLS_FLAGS_CERTUSER	0x20
#define	RPCTLS_FLAGS_HANDSHFAIL	0x40

/* Error return values for upcall rpcs. */
#define	RPCTLSERR_OK		0
#define	RPCTLSERR_NOCLOSE	1
#define	RPCTLSERR_NOSSL		2
#define	RPCTLSERR_NOSOCKET	3

#ifdef _KERNEL
/* Functions that perform upcalls to the rpctlsd daemon. */
enum clnt_stat	rpctls_connect(CLIENT *newclient, char *certname,
		    struct socket *so, uint64_t *sslp, uint32_t *reterr);
enum clnt_stat	rpctls_cl_handlerecord(uint64_t sec, uint64_t usec,
		    uint64_t ssl, uint32_t *reterr);
enum clnt_stat	rpctls_srv_handlerecord(uint64_t sec, uint64_t usec,
		    uint64_t ssl, int procpos, uint32_t *reterr);
enum clnt_stat	rpctls_cl_disconnect(uint64_t sec, uint64_t usec,
		    uint64_t ssl, uint32_t *reterr);
enum clnt_stat	rpctls_srv_disconnect(uint64_t sec, uint64_t usec,
		    uint64_t ssl, int procpos, uint32_t *reterr);

/* Initialization function for rpcsec_tls. */
int		rpctls_init(void);

/* Get TLS information function. */
bool		rpctls_getinfo(u_int *maxlen, bool rpctlscd_run,
		    bool rpctlssd_run);

/* String for AUTH_TLS reply verifier. */
#define	RPCTLS_START_STRING	"STARTTLS"

/* ssl refno value to indicate TLS handshake being done. */
#define	RPCTLS_REFNO_HANDSHAKE	0xFFFFFFFFFFFFFFFFULL

/* Macros for VIMAGE. */
/* Just define the KRPC_VNETxxx() macros as VNETxxx() macros. */
#define	KRPC_VNET_NAME(n)		VNET_NAME(n)
#define	KRPC_VNET_DECLARE(t, n)		VNET_DECLARE(t, n)
#define	KRPC_VNET_DEFINE(t, n)		VNET_DEFINE(t, n)
#define	KRPC_VNET_DEFINE_STATIC(t, n)	VNET_DEFINE_STATIC(t, n)
#define	KRPC_VNET(n)			VNET(n)

#define	CTLFLAG_KRPC_VNET		CTLFLAG_VNET

#define	KRPC_CURVNET_SET(n)		CURVNET_SET(n)
#define	KRPC_CURVNET_SET_QUIET(n)	CURVNET_SET_QUIET(n)
#define	KRPC_CURVNET_RESTORE()		CURVNET_RESTORE()
#define	KRPC_TD_TO_VNET(n)		TD_TO_VNET(n)

#endif	/* _KERNEL */

#endif	/* _RPC_RPCSEC_TLS_H_ */