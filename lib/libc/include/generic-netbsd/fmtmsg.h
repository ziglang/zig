/*	$NetBSD: fmtmsg.h,v 1.3 2008/04/28 20:22:54 martin Exp $	*/

/*-
 * Copyright (c) 1999 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus Klein.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _FMTMSG_H_
#define _FMTMSG_H_

/* Major Classifications: identifies the source of the condition. */
#define MM_HARD		0x01L	/* Hardware */
#define MM_SOFT		0x02L	/* Software */
#define MM_FIRM		0x03L	/* Firmware */

/* Message Source Subclassifications: type of software. */
#define MM_APPL		0x04L	/* Application */
#define MM_UTIL		0x08L	/* Utility */
#define MM_OPSYS	0x0cL	/* Operating system */

/* Display Subclassifications: where to display the message. */
#define MM_PRINT	0x10L	/* Display on standard error */
#define MM_CONSOLE	0x20L	/* Display on system console */

/* Status subclassifications: whether the application will recover. */
#define MM_RECOVER	0x40L	/* Recoverable */
#define MM_NRECOV	0x80L	/* Non-recoverable */

/* Severity: seriousness of the condition. */
#define MM_NOSEV	0	/* No severity level provided */
#define MM_HALT		1	/* Error causing application to halt */
#define MM_ERROR	2	/* Encountered a non-fatal fault */
#define MM_WARNING	3	/* Unusual non-error condition */
#define MM_INFO		4	/* Informative message */

/* `Null' values for message components. */
#define MM_NULLMC	0L		/* `Null' classsification component */
#define MM_NULLLBL	(char *)0	/* `Null' label component */
#define MM_NULLSEV	0		/* `Null' severity component */
#define MM_NULLTXT	(char *)0	/* `Null' text component */
#define MM_NULLACT	(char *)0	/* `Null' action component */
#define MM_NULLTAG	(char *)0	/* `Null' tag component */

/* Return values for fmtmsg(). */
#define MM_OK		0	/* Function succeeded */
#define MM_NOTOK	(-1)	/* Function failed completely */
#define MM_NOMSG	0x01	/* Unable to perform MM_PRINT */
#define MM_NOCON	0x02	/* Unable to perform MM_CONSOLE */

#include <sys/cdefs.h>

__BEGIN_DECLS
int	fmtmsg(long, const char *, int, const char *, const char *,
	    const char *);
__END_DECLS

#endif /* !_FMTMSG_H_ */