/*	$NetBSD: setjmp.h,v 1.3 2002/07/20 08:37:30 mrg Exp $	*/

/*
 * machine/setjmp.h: machine dependent setjmp-related information.
 */

#define	_JBLEN	14		/* size, in longs, of a jmp_buf */
				/* A sigcontext is 10 longs */