/*	$NetBSD: unistd.h,v 1.163.2.1 2024/10/09 13:12:40 martin Exp $	*/

/*-
 * Copyright (c) 1998, 1999, 2008 The NetBSD Foundation, Inc.
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

/*
 * Copyright (c) 1991, 1993, 1994
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
 *
 *	@(#)unistd.h	8.12 (Berkeley) 4/27/95
 */

#ifndef _UNISTD_H_
#define	_UNISTD_H_

#include <machine/ansi.h>
#include <machine/int_types.h>
#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <sys/types.h>
#include <sys/unistd.h>

#if _FORTIFY_SOURCE > 0
#include <ssp/unistd.h>
#endif

/*
 * IEEE Std 1003.1-90
 */
#define	STDIN_FILENO	0	/* standard input file descriptor */
#define	STDOUT_FILENO	1	/* standard output file descriptor */
#define	STDERR_FILENO	2	/* standard error file descriptor */

#include <sys/null.h>

__BEGIN_DECLS
__dead	 void _exit(int);
int	 access(const char *, int);
unsigned int alarm(unsigned int);
int	 chdir(const char *);
#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE)
int	chown(const char *, uid_t, gid_t) __RENAME(__posix_chown);
#else
int	chown(const char *, uid_t, gid_t);
#endif /* defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE) */
int	 close(int);
size_t	 confstr(int, char *, size_t);
#ifndef __CUSERID_DECLARED
#define __CUSERID_DECLARED
/* also declared in stdio.h */
char	*cuserid(char *);	/* obsolete */
#endif /* __CUSERID_DECLARED */
int	 dup(int);
int	 dup2(int, int);
int	 execl(const char *, const char *, ...) __null_sentinel;
int	 execle(const char *, const char *, ...);
int	 execlp(const char *, const char *, ...) __null_sentinel;
int	 execv(const char *, char * const *);
int	 execve(const char *, char * const *, char * const *);
int	 execvp(const char *, char * const *);
pid_t	 fork(void);
long	 fpathconf(int, int);
#if __SSP_FORTIFY_LEVEL == 0
char	*getcwd(char *, size_t);
#endif
gid_t	 getegid(void);
uid_t	 geteuid(void);
gid_t	 getgid(void);
int	 getgroups(int, gid_t []);
__aconst char *getlogin(void);
int	 getlogin_r(char *, size_t);
pid_t	 getpgrp(void);
pid_t	 getpid(void);
pid_t	 getppid(void);
uid_t	 getuid(void);
int	 isatty(int);
int	 link(const char *, const char *);
long	 pathconf(const char *, int);
int	 pause(void);
int	 pipe(int *);
#if __SSP_FORTIFY_LEVEL == 0
ssize_t	 read(int, void *, size_t);
#endif
int	 rmdir(const char *);
int	 setgid(gid_t);
int	 setpgid(pid_t, pid_t);
pid_t	 setsid(void);
int	 setuid(uid_t);
unsigned int	 sleep(unsigned int);
long	 sysconf(int);
pid_t	 tcgetpgrp(int);
int	 tcsetpgrp(int, pid_t);
__aconst char *ttyname(int);
int	 unlink(const char *);
ssize_t	 write(int, const void *, size_t);


/*
 * IEEE Std 1003.2-92, adopted in X/Open Portability Guide Issue 4 and later
 */
#if (_POSIX_C_SOURCE - 0) >= 2 || defined(_XOPEN_SOURCE) || \
    defined(_NETBSD_SOURCE)
int	 getopt(int, char * const [], const char *);

extern	 char *optarg;			/* getopt(3) external variables */
extern	 int opterr;
extern	 int optind;
extern	 int optopt;
#endif

/*
 * The Open Group Base Specifications, Issue 5; IEEE Std 1003.1-2001 (POSIX)
 */
#if (_POSIX_C_SOURCE - 0) >= 200112L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
#if __SSP_FORTIFY_LEVEL == 0
ssize_t	 readlink(const char * __restrict, char * __restrict, size_t);
#endif
#endif

/*
 * The Open Group Base Specifications, Issue 6; IEEE Std 1003.1-2001 (POSIX)
 */
#if (_POSIX_C_SOURCE - 0) >= 200112L || (_XOPEN_SOURCE - 0) >= 600 || \
    defined(_NETBSD_SOURCE)
int	 setegid(gid_t);
int	 seteuid(uid_t);
#endif

/*
 * The following three syscalls are also defined in <sys/types.h>
 * We protect them against double declarations.
 */
#ifndef __OFF_T_SYSCALLS_DECLARED
#define __OFF_T_SYSCALLS_DECLARED
off_t	 lseek(int, off_t, int);
int	 truncate(const char *, off_t);
/*
 * IEEE Std 1003.1b-93,
 * also found in X/Open Portability Guide >= Issue 4 Version 2
 */
#if (_POSIX_C_SOURCE - 0) >= 199309L || \
    (defined(_XOPEN_SOURCE) && defined(_XOPEN_SOURCE_EXTENDED)) || \
    (_XOPEN_SOURCE - 0) >= 500 || defined(_NETBSD_SOURCE)
int	 ftruncate(int, off_t);
#endif
#endif /* __OFF_T_SYSCALLS_DECLARED */


/*
 * IEEE Std 1003.1b-93, adopted in X/Open CAE Specification Issue 5 Version 2
 */
#if (_POSIX_C_SOURCE - 0) >= 199309L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
int	 fdatasync(int);
int	 fsync(int);
#endif


/*
 * IEEE Std 1003.1c-95, also adopted by X/Open CAE Spec Issue 5 Version 2
 */
#if (_POSIX_C_SOURCE - 0) >= 199506L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_REENTRANT) || defined(_NETBSD_SOURCE)
int	 ttyname_r(int, char *, size_t);
#ifndef __PTHREAD_ATFORK_DECLARED
#define __PTHREAD_ATFORK_DECLARED
int	 pthread_atfork(void (*)(void), void (*)(void), void (*)(void));
#endif
#endif

/*
 * X/Open Portability Guide, all issues
 */
#if defined(_XOPEN_SOURCE) || defined(_NETBSD_SOURCE)
int	 chroot(const char *);
int	 nice(int);
#endif


/*
 * X/Open Portability Guide >= Issue 4
 */
#if defined(_XOPEN_SOURCE) || defined(_NETBSD_SOURCE)
__aconst char *crypt(const char *, const char *);
int	 encrypt(char *, int);
char	*getpass(const char *);
#endif
#if defined(_XOPEN_SOURCE) || (_POSIX_C_SOURCE - 0) >= 200809L || \
    defined(_NETBSD_SOURCE)
pid_t	 getsid(pid_t);
#endif


/*
 * X/Open Portability Guide >= Issue 4 Version 2
 */
#if (defined(_XOPEN_SOURCE) && defined(_XOPEN_SOURCE_EXTENDED)) || \
    (_XOPEN_SOURCE - 0) >= 500 || defined(_NETBSD_SOURCE)
#ifndef _BSD_INTPTR_T_
typedef __intptr_t      intptr_t;
#define _BSD_INTPTR_T_
#endif

#define F_ULOCK		0
#define F_LOCK		1
#define F_TLOCK		2
#define F_TEST		3

int	 brk(void *);
int	 fchdir(int);
#if defined(_XOPEN_SOURCE)
int	 fchown(int, uid_t, gid_t) __RENAME(__posix_fchown);
#else
int	 fchown(int, uid_t, gid_t);
#endif
int	 getdtablesize(void);
long	 gethostid(void);
int	 gethostname(char *, size_t);
__pure int
	 getpagesize(void);		/* legacy */
pid_t	 getpgid(pid_t);
#if defined(_XOPEN_SOURCE)
int	 lchown(const char *, uid_t, gid_t) __RENAME(__posix_lchown);
#else
int	 lchown(const char *, uid_t, gid_t);
#endif
int	 lockf(int, int, off_t);
void	*sbrk(intptr_t);
/* XXX prototype wrong! */
int	 setpgrp(pid_t, pid_t);			/* obsoleted by setpgid() */
int	 setregid(gid_t, gid_t);
int	 setreuid(uid_t, uid_t);
void	 swab(const void * __restrict, void * __restrict, ssize_t);
int	 symlink(const char *, const char *);
void	 sync(void);
useconds_t ualarm(useconds_t, useconds_t);
int	 usleep(useconds_t);
#ifndef __LIBC12_SOURCE__
pid_t	 vfork(void) __RENAME(__vfork14) __returns_twice;
#endif

#ifndef __AUDIT__
char	*getwd(char *);				/* obsoleted by getcwd() */
#endif
#endif /* _XOPEN_SOURCE_EXTENDED || _XOPEN_SOURCE >= 500 || _NETBSD_SOURCE */


/*
 * X/Open CAE Specification Issue 5 Version 2
 */
#if (_POSIX_C_SOURCE - 0) >= 200112L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
ssize_t	 pread(int, void *, size_t, off_t);
ssize_t	 pwrite(int, const void *, size_t, off_t);
#endif /* (_POSIX_C_SOURCE - 0) >= 200112L || ... */

/*
 * X/Open Extended API set 2 (a.k.a. C063)
 */
#if (_POSIX_C_SOURCE - 0) >= 200809L || (_XOPEN_SOURCE - 0 >= 700) || \
    defined(_NETBSD_SOURCE)
int	linkat(int, const char *, int, const char *, int);
int	renameat(int, const char *, int, const char *);
int	faccessat(int, const char *, int, int);
int	fchownat(int, const char *, uid_t, gid_t, int);
ssize_t	readlinkat(int, const char *, char *, size_t);
int	symlinkat(const char *, int, const char *);
int	unlinkat(int, const char *, int);
int	fexecve(int, char * const *, char * const *);
#endif

/*
 * IEEE Std 1003.1-2024 (POSIX.1-2024)
 */
#if (_POSIX_C_SOURCE - 0) >= 202405L || (_XOPEN_SOURCE - 0 >= 800) || \
    defined(_NETBSD_SOURCE)
int	 getentropy(void *, size_t);
#endif


/*
 * Implementation-defined extensions
 */
#if defined(_NETBSD_SOURCE)
int	 acct(const char *);
int	 closefrom(int);
int	 des_cipher(const char *, char *, long, int);
int	 des_setkey(const char *);
int	 dup3(int, int, int);
void	 endusershell(void);
int	 exect(const char *, char * const *, char * const *);
int	 execvpe(const char *, char * const *, char * const *);
int	 execlpe(const char *, const char *, ...);
int	 fchroot(int);
int	 fdiscard(int, off_t, off_t);
int	 fsync_range(int, int, off_t, off_t);
int	 getdomainname(char *, size_t);
int	 getgrouplist(const char *, gid_t, gid_t *, int *);
int	 getgroupmembership(const char *, gid_t, gid_t *, int, int *);
mode_t	 getmode(const void *, mode_t);
char	*getpassfd(const char *, char *, size_t, int *, int, int);
#define	GETPASS_NEED_TTY	0x001	/* Fail if we cannot set tty */
#define	GETPASS_FAIL_EOF	0x002	/* Fail on EOF */
#define	GETPASS_BUF_LIMIT	0x004	/* beep on buffer limit */
#define	GETPASS_NO_SIGNAL	0x008	/* don't make ttychars send signals */
#define	GETPASS_NO_BEEP		0x010	/* don't beep */
#define	GETPASS_ECHO		0x020	/* echo characters as they are typed */
#define	GETPASS_ECHO_STAR	0x040	/* echo '*' for each character */
#define	GETPASS_7BIT		0x080	/* mask the high bit each char */
#define	GETPASS_FORCE_LOWER	0x100	/* lowercase each char */
#define	GETPASS_FORCE_UPPER	0x200	/* uppercase each char */
#define	GETPASS_ECHO_NL		0x400	/* echo a newline if successful */

char	*getpass_r(const char *, char *, size_t);
int	 getpeereid(int, uid_t *, gid_t *);
__aconst char *getusershell(void);
int	 initgroups(const char *, gid_t);
int	 iruserok(uint32_t, int, const char *, const char *);
int      issetugid(void);
long	 lpathconf(const char *, int);
int	 mkstemps(char *, int);
int	 nfssvc(int, void *);
int	 pipe2(int *, int);
int	 profil(char *, size_t, unsigned long, unsigned int);
#ifndef __PSIGNAL_DECLARED
#define __PSIGNAL_DECLARED
/* also in signal.h */
void	 psignal(int, const char *);
#endif /* __PSIGNAL_DECLARED */
int	 rcmd(char **, int, const char *, const char *, const char *, int *);
int	 reboot(int, char *);
int	 revoke(const char *);
int	 rresvport(int *);
int	 ruserok(const char *, int, const char *, const char *);
int	 setdomainname(const char *, size_t);
int	 setgroups(int, const gid_t *);
int	 sethostid(long);
int	 sethostname(const char *, size_t);
int	 setlogin(const char *);
void	*setmode(const char *);
int	 setrgid(gid_t);
int	 setruid(uid_t);
void	 setusershell(void);
void	 strmode(mode_t, char *);
#ifndef __STRSIGNAL_DECLARED
#define __STRSIGNAL_DECLARED
/* backwards-compatibility; also in string.h */
__aconst char *strsignal(int);
#endif /* __STRSIGNAL_DECLARED */
int	 swapctl(int, void *, int);
int	 swapon(const char *);			/* obsoleted by swapctl() */
int	 syscall(int, ...);
quad_t	 __syscall(quad_t, ...);
int	 undelete(const char *);

#if 1 /*INET6*/
int	 rcmd_af(char **, int, const char *,
	    const char *, const char *, int *, int);
int	 rresvport_af(int *, int);
int	 rresvport_af_addr(int *, int, void *);
int	 iruserok_sa(const void *, int, int, const char *, const char *);
#endif

#ifndef __SYS_SIGLIST_DECLARED
#define __SYS_SIGLIST_DECLARED
/* also in signal.h */
extern const char *const *sys_siglist __RENAME(__sys_siglist14);
#endif /* __SYS_SIGLIST_DECLARED */
extern	 int optreset;		/* getopt(3) external variable */
extern	 char *suboptarg;	/* getsubopt(3) external variable */
#endif

__END_DECLS
#endif /* !_UNISTD_H_ */