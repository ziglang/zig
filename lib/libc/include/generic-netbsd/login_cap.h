/*	$NetBSD: login_cap.h,v 1.13 2016/01/23 01:26:14 dholland Exp $	*/

/*-
 * Copyright (c) 1995,1997 Berkeley Software Design, Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Berkeley Software Design,
 *	Inc.
 * 4. The name of Berkeley Software Design, Inc.  may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BERKELEY SOFTWARE DESIGN, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL BERKELEY SOFTWARE DESIGN, INC. BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	BSDI login_cap.h,v 2.10 1997/08/07 21:35:19 prb Exp
 */

#ifndef _LOGIN_CAP_H_
#define _LOGIN_CAP_H_

#define	LOGIN_DEFCLASS		"default"
#define	LOGIN_DEFSERVICE	"login"
#define	LOGIN_DEFUMASK		022
#define	_PATH_LOGIN_CONF	"/etc/login.conf"

#define	LOGIN_OSETGROUP		0x0001	/* Obsolete setgroup */
#define	LOGIN_SETLOGIN		0x0002	/* Set login */
#define	LOGIN_SETPATH		0x0004	/* Set path */
#define	LOGIN_SETPRIORITY	0x0008	/* Set priority */
#define	LOGIN_SETRESOURCES	0x0010	/* Set resource limits */
#define	LOGIN_SETUMASK		0x0020	/* Set umask */
#define	LOGIN_SETUSER		0x0040	/* Set user */
#define	LOGIN_SETENV		0x0080	/* Set user environment */
#define	LOGIN_SETGID		0x0100	/* Set group id */
#define	LOGIN_SETGROUPS		0x0200	/* Set group membership (initgroups) */
#define	LOGIN_SETALL		0x03fe	/* Set all. 0x0001 is obsolete! */
#define	LOGIN_SETGROUP		(LOGIN_SETGID|LOGIN_SETGROUPS) /* Set group */

typedef struct {
	char	*lc_class;
	char	*lc_cap;
	char	*lc_style;
} login_cap_t;

typedef int (*envfunc_t)(void *, const char *, const char *, int);

#include <sys/cdefs.h>
__BEGIN_DECLS
struct passwd;

login_cap_t *login_getclass(const char *);
#ifndef __LIBC12_SOURCE__
login_cap_t *login_getpwclass(const struct passwd *)
    __RENAME(__login_getpwclass50);
#endif
void	 login_close(login_cap_t *);
int	 login_getcapbool(login_cap_t *, const char *, unsigned int);
quad_t	 login_getcapnum(login_cap_t *, const char *, quad_t, quad_t);
quad_t	 login_getcapsize(login_cap_t *, const char *, quad_t, quad_t);
char	*login_getcapstr(login_cap_t *, const char *, char *, char *);
quad_t	 login_getcaptime(login_cap_t *, const char *, quad_t, quad_t);

int	setclasscontext(const char *, unsigned int);
#ifndef __LIBC12_SOURCE__
int	setusercontext(login_cap_t *, struct passwd *, uid_t, unsigned int)
    __RENAME(__setusercontext50);
#endif
void	setuserpath(login_cap_t *, const char *, envfunc_t, void *);
int	setuserenv(login_cap_t *, envfunc_t, void *);

__END_DECLS

#endif	/* !_LOGIN_CAP_H_ */