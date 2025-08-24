/*	$NetBSD: types.h,v 1.4 2021/08/02 12:56:22 andvar Exp $	*/

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
 *	from: @(#)types.h 1.18 87/07/24 SMI
 *	@(#)types.h	2.3 88/08/15 4.0 RPCSRC
 */

/*
 * Rpc additions to <sys/types.h>
 */
#ifndef _RPC_TYPES_H_
#define _RPC_TYPES_H_

#include <sys/types.h>

typedef int32_t bool_t;
typedef int32_t enum_t;

typedef uint32_t rpcprog_t;
typedef uint32_t rpcvers_t;
typedef uint32_t rpcproc_t;
typedef uint32_t rpcprot_t;
typedef uint32_t rpcport_t;
typedef   int32_t rpc_inline_t;

#define __dontcare__	-1

#ifndef FALSE
#	define FALSE	(0)
#endif
#ifndef TRUE
#	define TRUE	(1)
#endif
#ifndef NULL
#	define NULL	0
#endif

#if defined(_KERNEL) || defined(_STANDALONE)

#define warn(msg,...) /**/

#include <sys/kmem.h>

#define mem_alloc(bsize)	kmem_alloc(bsize, KM_SLEEP)
#define mem_free(ptr, bsize)	kmem_free(ptr, bsize)

#else /* _KERNEL || _STANDALONE */

#define mem_alloc(bsize)	calloc((size_t)1, bsize)
#define mem_free(ptr, bsize)	free(ptr)

#include <sys/time.h>
#include <netconfig.h>

/*
 * The netbuf structure is defined here, because NetBSD only uses it inside
 * the RPC code. It's in <xti.h> on SVR4, but it would be confusing to
 * have an xti.h, since NetBSD does not support XTI/TLI.
 */

/*
 * The netbuf structure is used for transport-independent address storage.
 */
struct netbuf {
	unsigned int maxlen;
	unsigned int len;
	void *buf;
};

/*
 * The format of the address and options arguments of the XTI t_bind call.
 * Only provided for compatibility, it should not be used.
 */

struct t_bind {
	struct netbuf   addr;
	unsigned int    qlen;
};

/*
 * Internal library and rpcbind use. This is not an exported interface, do
 * not use.
 */
struct __rpc_sockinfo {
	int si_af; 
	int si_proto;
	int si_socktype;
	int si_alen;
};

#endif /* _KERNEL || _STANDALONE */

#endif /* !_RPC_TYPES_H_ */