/*	$NetBSD: rpcb_clnt.h,v 1.4 2009/01/11 03:04:12 christos Exp $	*/

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
 */
/*
 * Copyright (c) 1986 - 1991 by Sun Microsystems, Inc.
 */

/*
 * rpcb_clnt.h
 * Supplies C routines to get to rpcbid services.
 *
 */

/*
 * Usage:
 *	success = rpcb_set(program, version, nconf, address);
 *	success = rpcb_unset(program, version, nconf);
 *	success = rpcb_getaddr(program, version, nconf, host);
 *	head = rpcb_getmaps(nconf, host);
 *	clnt_stat = rpcb_rmtcall(nconf, host, program, version, procedure,
 *		xdrargs, argsp, xdrres, resp, tout, addr_ptr)
 *	success = rpcb_gettime(host, timep)
 *	uaddr = rpcb_taddr2uaddr(nconf, taddr);
 *	taddr = rpcb_uaddr2uaddr(nconf, uaddr);
 */

#ifndef _RPC_RPCB_CLNT_H
#define	_RPC_RPCB_CLNT_H

/* #pragma ident	"@(#)rpcb_clnt.h	1.13	94/04/25 SMI" */
/* rpcb_clnt.h 1.3 88/12/05 SMI */

#include <rpc/types.h>
#include <rpc/rpcb_prot.h>

__BEGIN_DECLS
extern bool_t rpcb_set(const rpcprog_t, const rpcvers_t,
			const struct netconfig  *, const struct netbuf *);
extern bool_t rpcb_unset(const rpcprog_t, const rpcvers_t,
			 const struct netconfig *);
extern rpcblist	*rpcb_getmaps(const struct netconfig *, const char *);
#ifndef __LIBC12_SOURCE__
extern enum clnt_stat rpcb_rmtcall(const struct netconfig *,
				   const char *, const rpcprog_t,
				   const rpcvers_t, const rpcproc_t,
				   const xdrproc_t, const char *,
				   const xdrproc_t, caddr_t,
				   const struct timeval,
				   const struct netbuf *)
				   __RENAME(__rpcb_rmtcall50);
#endif
extern bool_t rpcb_getaddr(const rpcprog_t, const rpcvers_t,
			   const struct netconfig *, struct netbuf *,
			   const  char *);
#ifndef __LIBC12_SOURCE__
extern bool_t rpcb_gettime(const char *, time_t *)
    __RENAME(__rpcb_gettime50);
#endif
extern char *rpcb_taddr2uaddr(struct netconfig *, struct netbuf *);
extern struct netbuf *rpcb_uaddr2taddr(struct netconfig *, char *);
__END_DECLS

#endif	/* !_RPC_RPCB_CLNT_H */