/*	$OpenBSD: libgen.h,v 1.4 1999/05/28 22:00:22 espie Exp $	*/
/*	$FreeBSD: src/include/libgen.h,v 1.1.2.1 2000/11/12 18:01:51 adrian Exp $	*/

/*
 * Copyright (c) 1997 Todd C. Miller <Todd.Miller@courtesan.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _LIBGEN_H_
#define _LIBGEN_H_

#include <sys/cdefs.h>

__BEGIN_DECLS

#if __DARWIN_UNIX03

char	*basename(char *);
char	*dirname(char *);

#else  /* !__DARWIN_UNIX03 */

char	*basename(const char *);
char	*dirname(const char *);

#endif /* __DARWIN_UNIX_03 */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#include <Availability.h>
char	*basename_r(const char *, char *)
		__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0)
		__TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

char	*dirname_r(const char *, char *)
		__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0)
		__TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

__END_DECLS

#endif /* _LIBGEN_H_ */