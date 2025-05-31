/*	$NetBSD: svc_soc.h,v 1.4 2016/01/23 02:34:09 dholland Exp $	*/

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
 * svc.h, Server-side remote procedure call interface.
 */

#ifndef _RPC_SVC_SOC_H
#define _RPC_SVC_SOC_H
#include <sys/cdefs.h>

/* #pragma ident   "@(#)svc_soc.h  1.11    94/04/25 SMI" */
/*      svc_soc.h 1.8 89/05/01 SMI      */

/*
 * All the following declarations are only for backward compatibility
 * with TS-RPC
 */

/*
 *  Approved way of getting address of caller
 */
#define svc_getcaller(x) (&(x)->xp_raddr)

/*
 * Service registration
 *
 * svc_register(xprt, prog, vers, dispatch, protocol)
 *	SVCXPRT *xprt;
 *	unsigned long prog;
 *	unsigned long vers;
 *	void (*dispatch)();
 *	int protocol;    like TCP or UDP, zero means do not register 
 */
__BEGIN_DECLS
extern bool_t	svc_register(SVCXPRT *, unsigned long, unsigned long,
		    void (*)(struct svc_req *, SVCXPRT *), int);
__END_DECLS

/*
 * Service un-registration
 *
 * svc_unregister(prog, vers)
 *	unsigned long prog;
 *	unsigned long vers;
 */
__BEGIN_DECLS
extern void	svc_unregister(unsigned long, unsigned long);
__END_DECLS


/*
 * Memory based rpc for testing and timing.
 */
__BEGIN_DECLS
extern SVCXPRT *svcraw_create(void);
__END_DECLS


/*
 * Udp based rpc.
 */
__BEGIN_DECLS
extern SVCXPRT *svcudp_create(int);
extern SVCXPRT *svcudp_bufcreate(int, unsigned int, unsigned int);
extern int svcudp_enablecache(SVCXPRT *, unsigned long);
__END_DECLS


/*
 * Tcp based rpc.
 */
__BEGIN_DECLS
extern SVCXPRT *svctcp_create(int, unsigned int, unsigned int);
__END_DECLS

/*
 * Fd based rpc.
 */
__BEGIN_DECLS
extern SVCXPRT *svcfd_create(int, unsigned int, unsigned int);
__END_DECLS

#endif /* !_RPC_SVC_SOC_H */