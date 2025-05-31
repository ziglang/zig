/*	$NetBSD: util.h,v 1.69 2016/04/10 19:05:50 roy Exp $	*/

/*-
 * Copyright (c) 1995
 *	The Regents of the University of California.  All rights reserved.
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
 */

#ifndef _UTIL_H_
#define	_UTIL_H_

#include <sys/cdefs.h>
#include <sys/types.h>
#include <sys/ansi.h>
#include <sys/inttypes.h>

#ifdef  _BSD_TIME_T_
typedef _BSD_TIME_T_    time_t;
#undef  _BSD_TIME_T_
#endif
#ifdef  _BSD_SIZE_T_
typedef _BSD_SIZE_T_    size_t;
#undef  _BSD_SIZE_T_
#endif
 
#if defined(_POSIX_C_SOURCE)
#ifndef __VA_LIST_DECLARED
typedef __va_list va_list;
#define __VA_LIST_DECLARED
#endif
#endif

#define	PIDLOCK_NONBLOCK	1
#define	PIDLOCK_USEHOSTNAME	2

#define	PW_POLICY_BYSTRING	0
#define	PW_POLICY_BYPASSWD	1
#define	PW_POLICY_BYGROUP	2

__BEGIN_DECLS
struct disklabel;
struct iovec;
struct passwd;
struct termios;
struct utmp;
struct utmpx;
struct winsize;
struct sockaddr;

char	       *flags_to_string(unsigned long, const char *);
pid_t		forkpty(int *, char *, struct termios *, struct winsize *);
const char     *getbootfile(void);
int		getbyteorder(void);
off_t		getlabeloffset(void);
int		getlabelsector(void);
int		getlabelusesmbr(void);
int		getmaxpartitions(void);
int		getrawpartition(void);
const char     *getdiskrawname(char *, size_t, const char *);
const char     *getdiskcookedname(char *, size_t, const char *);
const char     *getfstypename(int);
const char     *getfsspecname(char *, size_t, const char *);
struct kinfo_vmentry *kinfo_getvmmap(pid_t, size_t *);
#ifndef __LIBC12_SOURCE__
void		login(const struct utmp *) __RENAME(__login50);
void		loginx(const struct utmpx *) __RENAME(__loginx50);
#endif
int		login_tty(int);
int		logout(const char *);
int		logoutx(const char *, int, int);
void		logwtmp(const char *, const char *, const char *);
void		logwtmpx(const char *, const char *, const char *, int, int);
int		opendisk(const char *, int, char *, size_t, int);
int		opendisk1(const char *, int, char *, size_t, int,
			  int (*)(const char *, int, ...));
int		openpty(int *, int *, char *, struct termios *,
    struct winsize *);
#ifndef __LIBC12_SOURCE__
time_t		parsedate(const char *, const time_t *, const int *)
    __RENAME(__parsedate50);
#endif
int		pidfile(const char *);
pid_t		pidfile_lock(const char *);
pid_t		pidfile_read(const char *);
int		pidfile_clean(void);
int		pidlock(const char *, int, pid_t *, const char *);
int		pw_abort(void);
#ifndef __LIBC12_SOURCE__
void		pw_copy(int, int, struct passwd *, struct passwd *)
    __RENAME(__pw_copy50);
int		pw_copyx(int, int, struct passwd *, struct passwd *,
    char *, size_t) __RENAME(__pw_copyx50);
#endif
void		pw_edit(int, const char *);
__dead void	pw_error(const char *, int, int);
void		pw_getconf(char *, size_t, const char *, const char *);
#ifndef __LIBC12_SOURCE__
void		pw_getpwconf(char *, size_t, const struct passwd *,
    const char *) __RENAME(__pw_getpwconf50);
#endif
const char     *pw_getprefix(void);
void		pw_init(void);
int		pw_lock(int);
int		pw_mkdb(const char *, int);
void		pw_prompt(void);
int		pw_setprefix(const char *);
int		raise_default_signal(int);
int		secure_path(const char *);
int		snprintb_m(char *, size_t, const char *, uint64_t, size_t);
int		snprintb(char *, size_t, const char *, uint64_t);
int		sockaddr_snprintf(char *, size_t, const char *,
    const struct sockaddr *);
char 	       *strpct(char *, size_t, uintmax_t, uintmax_t, size_t);
char 	       *strspct(char *, size_t, intmax_t, intmax_t, size_t);
int		string_to_flags(char **, unsigned long *, unsigned long *);
int		ttyaction(const char *, const char *, const char *);
int		ttylock(const char *, int, pid_t *);
char	       *ttymsg(struct iovec *, int, const char *, int);
int		ttyunlock(const char *);

uint16_t	disklabel_dkcksum(struct disklabel *);
int		disklabel_scan(struct disklabel *, char *, size_t);

/* Error checked functions */
void		(*esetfunc(void (*)(int, const char *, ...)))
    (int, const char *, ...);
size_t 		estrlcpy(char *, const char *, size_t);
size_t 		estrlcat(char *, const char *, size_t);
char 		*estrdup(const char *);
char 		*estrndup(const char *, size_t);
intmax_t	estrtoi(const char *, int, intmax_t, intmax_t);
uintmax_t	estrtou(const char *, int, uintmax_t, uintmax_t);
void 		*ecalloc(size_t, size_t);
void 		*emalloc(size_t);
void 		*erealloc(void *, size_t);
void 		ereallocarr(void *, size_t, size_t);
struct __sFILE	*efopen(const char *, const char *);
int	 	easprintf(char ** __restrict, const char * __restrict, ...)
			__printflike(2, 3);
int		evasprintf(char ** __restrict, const char * __restrict,
    __va_list) __printflike(2, 0);
__END_DECLS

#endif /* !_UTIL_H_ */