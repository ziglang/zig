/*	$NetBSD: openfirmio.h,v 1.7 2015/09/06 06:01:00 dholland Exp $ */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)openpromio.h	8.1 (Berkeley) 6/11/93
 */
#ifndef _DEV_OFW_OPENFIRMIO_H_
#define _DEV_OFW_OPENFIRMIO_H_

#include <sys/ioccom.h>

struct ofiocdesc {
	int	of_nodeid;		/* passed or returned node id */
	int	of_namelen;		/* length of op_name */
	char	*of_name;		/* pointer to field name */
	int	of_buflen;		/* length of op_buf (value-result) */
	char	*of_buf;		/* pointer to field value */
};

#define	OFIOCGET	_IOWR('O', 1, struct ofiocdesc) /* get openprom field */
#define	OFIOCSET	_IOW('O', 2, struct ofiocdesc) /* set openprom field */
#define	OFIOCNEXTPROP	_IOWR('O', 3, struct ofiocdesc) /* get next property */
#define	OFIOCGETOPTNODE	_IOR('O', 4, int)	/* get options node */
#define	OFIOCGETNEXT	_IOWR('O', 5, int)	/* get next node of node */
#define	OFIOCGETCHILD	_IOWR('O', 6, int)	/* get first child of node */
#define	OFIOCFINDDEVICE	_IOWR('O', 7, struct ofiocdesc) /* find a specific device */

#endif /* _DEV_OFW_OPENFIRMIO_H_ */