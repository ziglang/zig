/*	$NetBSD: rpcent.h,v 1.3 2005/02/03 04:39:32 perry Exp $	*/

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
 * rpcent.h,
 * For converting rpc program numbers to names etc.
 *
 */

#ifndef _RPC_RPCENT_H
#define _RPC_RPCENT_H

/*	#pragma ident "@(#)rpcent.h   1.13    94/04/25 SMI"	*/
/*      @(#)rpcent.h 1.1 88/12/06 SMI   */


struct rpcent {
      char    *r_name;        /* name of server for this rpc program */
      char    **r_aliases;    /* alias list */
      int     r_number;       /* rpc program number */
};

__BEGIN_DECLS
extern struct rpcent *getrpcbyname_r(const char *, struct rpcent *,
					  char *, int);
extern struct rpcent *getrpcbynumber_r(int, struct rpcent *, char *, int);
extern struct rpcent *getrpcent_r(struct rpcent *, char *, int);

/* Old interfaces that return a pointer to a static area;  MT-unsafe */
extern struct rpcent *getrpcbyname(const char *);
extern struct rpcent *getrpcbynumber(int);
extern struct rpcent *getrpcent(void);
extern void setrpcent(int);
extern void endrpcent(void);
__END_DECLS

#endif /* !_RPC_ENT_H_ */