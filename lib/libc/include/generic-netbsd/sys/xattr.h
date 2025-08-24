/*	$NetBSD: xattr.h,v 1.5 2011/09/27 01:40:32 christos Exp $	*/

/*-
 * Copyright (c) 2005 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
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

/*
 * Support for file system extended attributes.
 *
 * This provides an interface that is compatible with Linux's extended
 * attribute support.  These calls operate on the same extended attributes
 * as <sys/extattr.h>, but access only the "user" namespace.
 */

#ifndef _SYS_XATTR_H_
#define	_SYS_XATTR_H_

#include <sys/types.h>
#include <sys/param.h>

/*
 * This is compatible with EXTATTR_MAXNAMELEN, and also happens to be
 * the same as Linux (255).
 */
#define	XATTR_NAME_MAX		KERNEL_NAME_MAX

#define	XATTR_SIZE_MAX		65536	/* NetBSD does not enforce this */

#define	XATTR_CREATE		0x01	/* create, don't replace xattr */
#define	XATTR_REPLACE		0x02	/* replace, don't create xattr */

#ifndef _KERNEL

#include <sys/cdefs.h>

__BEGIN_DECLS
int	setxattr(const char *, const char *, const void *, size_t, int);
int	lsetxattr(const char *, const char *, const void *, size_t, int);
int	fsetxattr(int, const char *, const void *, size_t, int);

ssize_t	getxattr(const char *, const char *, void *, size_t);
ssize_t	lgetxattr(const char *, const char *, void *, size_t);
ssize_t	fgetxattr(int, const char *, void *, size_t);

ssize_t	listxattr(const char *, char *, size_t);
ssize_t	llistxattr(const char *, char *, size_t);
ssize_t	flistxattr(int, char *, size_t);

int	removexattr(const char *, const char *);
int	lremovexattr(const char *, const char *);
int	fremovexattr(int, const char *);
__END_DECLS

#endif /* ! _KERNEL */

#endif /* _SYS_XATTR_H_ */