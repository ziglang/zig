/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2013 Mark Johnston <markj@FreeBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the
 *    distribution.
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

#ifndef _SYS_IN_KDTRACE_H_
#define	_SYS_IN_KDTRACE_H_

#define	IP_PROBE(probe, arg0, arg1, arg2, arg3, arg4, arg5)		\
	SDT_PROBE6(ip, , , probe, arg0, arg1, arg2, arg3, arg4, arg5)
#define	UDP_PROBE(probe, arg0, arg1, arg2, arg3, arg4)			\
	SDT_PROBE5(udp, , , probe, arg0, arg1, arg2, arg3, arg4)
#define	UDPLITE_PROBE(probe, arg0, arg1, arg2, arg3, arg4)		\
	SDT_PROBE5(udplite, , , probe, arg0, arg1, arg2, arg3, arg4)
#define	TCP_PROBE1(probe, arg0)						\
	SDT_PROBE1(tcp, , , probe, arg0)
#define	TCP_PROBE2(probe, arg0, arg1)					\
	SDT_PROBE2(tcp, , , probe, arg0, arg1)
#define	TCP_PROBE3(probe, arg0, arg1, arg2)				\
	SDT_PROBE3(tcp, , , probe, arg0, arg1, arg2)
#define	TCP_PROBE4(probe, arg0, arg1, arg2, arg3)			\
	SDT_PROBE4(tcp, , , probe, arg0, arg1, arg2, arg3)
#define	TCP_PROBE5(probe, arg0, arg1, arg2, arg3, arg4)			\
	SDT_PROBE5(tcp, , , probe, arg0, arg1, arg2, arg3, arg4)
#define	TCP_PROBE6(probe, arg0, arg1, arg2, arg3, arg4, arg5)		\
	SDT_PROBE6(tcp, , , probe, arg0, arg1, arg2, arg3, arg4, arg5)

SDT_PROVIDER_DECLARE(ip);
SDT_PROVIDER_DECLARE(tcp);
SDT_PROVIDER_DECLARE(udp);
SDT_PROVIDER_DECLARE(udplite);

SDT_PROBE_DECLARE(ip, , , receive);
SDT_PROBE_DECLARE(ip, , , send);

SDT_PROBE_DECLARE(tcp, , , accept__established);
SDT_PROBE_DECLARE(tcp, , , accept__refused);
SDT_PROBE_DECLARE(tcp, , , connect__established);
SDT_PROBE_DECLARE(tcp, , , connect__refused);
SDT_PROBE_DECLARE(tcp, , , connect__request);
SDT_PROBE_DECLARE(tcp, , , receive);
SDT_PROBE_DECLARE(tcp, , , send);
SDT_PROBE_DECLARE(tcp, , , siftr);
SDT_PROBE_DECLARE(tcp, , , state__change);
SDT_PROBE_DECLARE(tcp, , , debug__input);
SDT_PROBE_DECLARE(tcp, , , debug__output);
SDT_PROBE_DECLARE(tcp, , , debug__user);
SDT_PROBE_DECLARE(tcp, , , debug__drop);
SDT_PROBE_DECLARE(tcp, , , receive__autoresize);

SDT_PROBE_DECLARE(udp, , , receive);
SDT_PROBE_DECLARE(udp, , , send);

SDT_PROBE_DECLARE(udplite, , , receive);
SDT_PROBE_DECLARE(udplite, , , send);

/*
 * These constants originate from the 4.4BSD sys/protosw.h.  They lost
 * their initial purpose in 2c37256e5a59, when single pr_usrreq method
 * was split into multiple methods.  However, they were used by TCPDEBUG,
 * a feature barely used, but it kept them in the tree for many years.
 * In 5d06879adb95 DTrace probes started to use them.  Note that they
 * are not documented in dtrace_tcp(4), so they are likely to be
 * eventually renamed to something better and extended/trimmed.
 */
#define	PRU_ATTACH		0	/* attach protocol to up */
#define	PRU_DETACH		1	/* detach protocol from up */
#define	PRU_BIND		2	/* bind socket to address */
#define	PRU_LISTEN		3	/* listen for connection */
#define	PRU_CONNECT		4	/* establish connection to peer */
#define	PRU_ACCEPT		5	/* accept connection from peer */
#define	PRU_DISCONNECT		6	/* disconnect from peer */
#define	PRU_SHUTDOWN		7	/* won't send any more data */
#define	PRU_RCVD		8	/* have taken data; more room now */
#define	PRU_SEND		9	/* send this data */
#define	PRU_ABORT		10	/* abort (fast DISCONNECT, DETATCH) */
#define	PRU_CONTROL		11	/* control operations on protocol */
#define	PRU_SENSE		12	/* return status into m */
#define	PRU_RCVOOB		13	/* retrieve out of band data */
#define	PRU_SENDOOB		14	/* send out of band data */
#define	PRU_SOCKADDR		15	/* fetch socket's address */
#define	PRU_PEERADDR		16	/* fetch peer's address */
#define	PRU_CONNECT2		17	/* connect two sockets */
/* begin for protocols internal use */
#define	PRU_FASTTIMO		18	/* 200ms timeout */
#define	PRU_SLOWTIMO		19	/* 500ms timeout */
#define	PRU_PROTORCV		20	/* receive from below */
#define	PRU_PROTOSEND		21	/* send to below */
/* end for protocol's internal use */
#define PRU_SEND_EOF		22	/* send and close */
#define	PRU_SOSETLABEL		23	/* MAC label change */
#define	PRU_CLOSE		24	/* socket close */
#define	PRU_FLUSH		25	/* flush the socket */
#define	PRU_NREQ		25

#ifdef PRUREQUESTS
const char *prurequests[] = {
	"ATTACH",	"DETACH",	"BIND",		"LISTEN",
	"CONNECT",	"ACCEPT",	"DISCONNECT",	"SHUTDOWN",
	"RCVD",		"SEND",		"ABORT",	"CONTROL",
	"SENSE",	"RCVOOB",	"SENDOOB",	"SOCKADDR",
	"PEERADDR",	"CONNECT2",	"FASTTIMO",	"SLOWTIMO",
	"PROTORCV",	"PROTOSEND",	"SEND_EOF",	"SOSETLABEL",
	"CLOSE",	"FLUSH",
};
#endif

#endif