/*	$NetBSD: clnt_soc.h,v 1.5 2016/01/23 02:34:09 dholland Exp $	*/

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
 * Copyright (c) 1984 - 1991 by Sun Microsystems, Inc.
 */

/*
 * clnt.h - Client side remote procedure call interface.
 */

#ifndef _RPC_CLNT_SOC_H
#define _RPC_CLNT_SOC_H

/* derived from clnt_soc.h 1.3 88/12/17 SMI     */

/*
 * All the following declarations are only for backward compatibility
 * with TS-RPC.
 */

#include <sys/cdefs.h>

#define UDPMSGSIZE      8800    /* rpc imposed limit on udp msg size */  

/*
 * TCP based rpc
 * CLIENT *
 * clnttcp_create(raddr, prog, vers, sockp, sendsz, recvsz)
 *	struct sockaddr_in *raddr;
 *	unsigned long prog;
 *	unsigned long version;
 *	int *sockp;
 *	unsigned sendsz;
 *	unsigned recvsz;
 */
__BEGIN_DECLS
extern CLIENT *clnttcp_create(struct sockaddr_in *,
				unsigned long,
				unsigned long,
				int *,
				unsigned int,
				unsigned int);
__END_DECLS

/*
 * Raw (memory) rpc.
 */
__BEGIN_DECLS
extern CLIENT *clntraw_create  (unsigned long, unsigned long);
__END_DECLS


/*
 * UDP based rpc.
 * CLIENT *
 * clntudp_create(raddr, program, version, wait, sockp)
 *	struct sockaddr_in *raddr;
 *	unsigned long program;
 *	unsigned long version;
 *	struct timeval wait;
 *	int *sockp;
 *
 * Same as above, but you specify max packet sizes.
 * CLIENT *
 * clntudp_bufcreate(raddr, program, version, wait, sockp, sendsz, recvsz)
 *	struct sockaddr_in *raddr;
 *	unsigned long program;
 *	unsigned long version;
 *	struct timeval wait;
 *	int *sockp;
 *	unsigned sendsz;
 *	unsigned recvsz;
 */
__BEGIN_DECLS
extern CLIENT *clntudp_create(struct sockaddr_in *,
				unsigned long,
				unsigned long,
				struct timeval,
				int *);
extern CLIENT *clntudp_bufcreate(struct sockaddr_in *,
				     unsigned long,
				     unsigned long,
				     struct timeval,
				     int *,
				     unsigned int,
				     unsigned int);
__END_DECLS

#endif /* _RPC_CLNT_SOC_H */