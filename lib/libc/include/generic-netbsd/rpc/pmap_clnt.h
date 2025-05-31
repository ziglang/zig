/*	$NetBSD: pmap_clnt.h,v 1.13 2016/01/23 02:34:09 dholland Exp $	*/

/*
 * Sun RPC is a product of Sun Microsystems, Inc. and is provided for
 * unrestricted use provided that this legend is included on all tape
 * media and as a part of the software program in whole or part.  Users
 * may copy or modify Sun RPC without charge, but are not authorized
 * to license or distribute it to anyone else except as part of a product or
 * program developed by the user.
 * 
 * SUN RPC IS PROVIDED AS IS WITH NO WARRANTIES OF ANY KIND INCLUDING THE
 * WARRANTIES OF DESIGN, MERCHANTIBILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE, OR ARISING FROM A COURSE OF DEALING, USAGE OR TRADE PRACTICE.
 * 
 * Sun RPC is provided with no support and without any obligation on the
 * part of Sun Microsystems, Inc. to assist in its use, correction,
 * modification or enhancement.
 * 
 * SUN MICROSYSTEMS, INC. SHALL HAVE NO LIABILITY WITH RESPECT TO THE
 * INFRINGEMENT OF COPYRIGHTS, TRADE SECRETS OR ANY PATENTS BY SUN RPC
 * OR ANY PART THEREOF.
 * 
 * In no event will Sun Microsystems, Inc. be liable for any lost revenue
 * or profits or other special, indirect and consequential damages, even if
 * Sun has been advised of the possibility of such damages.
 * 
 * Sun Microsystems, Inc.
 * 2550 Garcia Avenue
 * Mountain View, California  94043
 *
 *	from: @(#)pmap_clnt.h 1.11 88/02/08 SMI 
 *	@(#)pmap_clnt.h	2.1 88/07/29 4.0 RPCSRC
 */

/*
 * pmap_clnt.h
 * Supplies C routines to get to portmap services.
 *
 * Copyright (C) 1984, Sun Microsystems, Inc.
 */

/*
 * Usage:
 *	success = pmap_set(program, version, protocol, port);
 *	success = pmap_unset(program, version);
 *	port = pmap_getport(address, program, version, protocol);
 *	head = pmap_getmaps(address);
 *	clnt_stat = pmap_rmtcall(address, program, version, procedure,
 *		xdrargs, argsp, xdrres, resp, tout, port_ptr)
 *		(works for udp only.) 
 * 	clnt_stat = clnt_broadcast(program, version, procedure,
 *		xdrargs, argsp,	xdrres, resp, eachresult)
 *		(like pmap_rmtcall, except the call is broadcasted to all
 *		locally connected nets.  For each valid response received,
 *		the procedure eachresult is called.  Its form is:
 *	done = eachresult(resp, raddr)
 *		bool_t done;
 *		caddr_t resp;
 *		struct sockaddr_in raddr;
 *		where resp points to the results of the call and raddr is the
 *		address if the responder to the broadcast.
 */

#ifndef _RPC_PMAP_CLNT_H_
#define _RPC_PMAP_CLNT_H_
#include <sys/cdefs.h>

__BEGIN_DECLS
extern bool_t		pmap_set(unsigned long, unsigned long, int, int);
extern bool_t		pmap_unset(unsigned long, unsigned long);
extern struct pmaplist	*pmap_getmaps(struct sockaddr_in *);
#ifndef __LIBC12_SOURCE__
extern enum clnt_stat	pmap_rmtcall(struct sockaddr_in *,
					unsigned long, unsigned long,
					unsigned long,
					xdrproc_t, caddr_t,
					xdrproc_t, caddr_t,
					struct timeval, unsigned long *)
					__RENAME(__pmap_rmtcall50);
#endif
extern enum clnt_stat	clnt_broadcast(unsigned long, unsigned long,
					unsigned long,
					xdrproc_t, char *,
					xdrproc_t, char *,
					resultproc_t);
extern unsigned short	pmap_getport(struct sockaddr_in *,
					unsigned long, unsigned long,
					unsigned int);
__END_DECLS

#endif /* !_RPC_PMAP_CLNT_H_ */