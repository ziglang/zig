/*	$NetBSD: nettype.h,v 1.3 2005/02/03 04:39:32 perry Exp $	*/

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
 * nettype.h, Nettype definitions.
 * All for the topmost layer of rpc
 *
 */

#ifndef	_RPC_NETTYPE_H
#define	_RPC_NETTYPE_H

#include <netconfig.h>

#define	_RPC_NONE	0
#define	_RPC_NETPATH	1
#define	_RPC_VISIBLE	2
#define	_RPC_CIRCUIT_V	3
#define	_RPC_DATAGRAM_V	4
#define	_RPC_CIRCUIT_N	5
#define	_RPC_DATAGRAM_N	6
#define	_RPC_TCP	7
#define	_RPC_UDP	8

__BEGIN_DECLS
extern void *__rpc_setconf(const char *);
extern void __rpc_endconf(void *);
extern struct netconfig *__rpc_getconf(void *);
extern struct netconfig *__rpc_getconfip(const char *);
__END_DECLS

#endif	/* !_RPC_NETTYPE_H */