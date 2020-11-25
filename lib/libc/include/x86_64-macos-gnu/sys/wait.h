/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1982, 1986, 1989, 1993, 1994
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)wait.h	8.2 (Berkeley) 7/10/94
 */

#ifndef _SYS_WAIT_H_
#define _SYS_WAIT_H_

#include <sys/cdefs.h>
#include <sys/_types.h>

/*
 * This file holds definitions relevent to the wait4 system call
 * and the alternate interfaces that use it (wait, wait3, waitpid).
 */

/*
 * [XSI] The type idtype_t shall be defined as an enumeration type whose
 * possible values shall include at least P_ALL, P_PID, and P_PGID.
 */
typedef enum {
	P_ALL,
	P_PID,
	P_PGID
} idtype_t;

/*
 * [XSI] The id_t and pid_t types shall be defined as described
 * in <sys/types.h>
 */
#include <sys/_types/_pid_t.h>
#include <sys/_types/_id_t.h>

/*
 * [XSI] The siginfo_t type shall be defined as described in <signal.h>
 * [XSI] The rusage structure shall be defined as described in <sys/resource.h>
 * [XSI] Inclusion of the <sys/wait.h> header may also make visible all
 * symbols from <signal.h> and <sys/resource.h>
 *
 * NOTE:	This requirement is currently being satisfied by the direct
 *		inclusion of <sys/signal.h> and <sys/resource.h>, below.
 *
 *		Software should not depend on the exposure of anything other
 *		than the types siginfo_t and struct rusage as a result of
 *		this inclusion.  If you depend on any types or manifest
 *		values othe than siginfo_t and struct rusage from either of
 *		those files, you should explicitly include them yourself, as
 *		well, or in future releases your stware may not compile
 *		without modification.
 */
#include <sys/signal.h>         /* [XSI] for siginfo_t */
#include <sys/resource.h>       /* [XSI] for struct rusage */

/*
 * Option bits for the third argument of wait4.  WNOHANG causes the
 * wait to not hang if there are no stopped or terminated processes, rather
 * returning an error indication in this case (pid==0).  WUNTRACED
 * indicates that the caller should receive status about untraced children
 * which stop due to signals.  If children are stopped and a wait without
 * this option is done, it is as though they were still running... nothing
 * about them is returned.
 */
#define WNOHANG         0x00000001  /* [XSI] no hang in wait/no child to reap */
#define WUNTRACED       0x00000002  /* [XSI] notify on stop, untraced child */

/*
 * Macros to test the exit status returned by wait
 * and extract the relevant values.
 */
#if defined(_POSIX_C_SOURCE) && !defined(_DARWIN_C_SOURCE)
#define _W_INT(i)       (i)
#else
#define _W_INT(w)       (*(int *)&(w))  /* convert union wait to int */
#define WCOREFLAG       0200
#endif /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */

/* These macros are permited, as they are in the implementation namespace */
#define _WSTATUS(x)     (_W_INT(x) & 0177)
#define _WSTOPPED       0177            /* _WSTATUS if process is stopped */

/*
 * [XSI] The <sys/wait.h> header shall define the following macros for
 * analysis of process status values
 */
#if __DARWIN_UNIX03
#define WEXITSTATUS(x)  ((_W_INT(x) >> 8) & 0x000000ff)
#else /* !__DARWIN_UNIX03 */
#define WEXITSTATUS(x)  (_W_INT(x) >> 8)
#endif /* !__DARWIN_UNIX03 */
/* 0x13 == SIGCONT */
#define WSTOPSIG(x)     (_W_INT(x) >> 8)
#define WIFCONTINUED(x) (_WSTATUS(x) == _WSTOPPED && WSTOPSIG(x) == 0x13)
#define WIFSTOPPED(x)   (_WSTATUS(x) == _WSTOPPED && WSTOPSIG(x) != 0x13)
#define WIFEXITED(x)    (_WSTATUS(x) == 0)
#define WIFSIGNALED(x)  (_WSTATUS(x) != _WSTOPPED && _WSTATUS(x) != 0)
#define WTERMSIG(x)     (_WSTATUS(x))
#if (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#define WCOREDUMP(x)    (_W_INT(x) & WCOREFLAG)

#define W_EXITCODE(ret, sig)    ((ret) << 8 | (sig))
#define W_STOPCODE(sig)         ((sig) << 8 | _WSTOPPED)
#endif /* (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)) */

/*
 * [XSI] The following symbolic constants shall be defined as possible
 * values for the fourth argument to waitid().
 */
/* WNOHANG already defined for wait4() */
/* WUNTRACED defined for wait4() but not for waitid() */
#define WEXITED         0x00000004  /* [XSI] Processes which have exitted */
#if __DARWIN_UNIX03
/* waitid() parameter */
#define WSTOPPED        0x00000008  /* [XSI] Any child stopped by signal */
#endif
#define WCONTINUED      0x00000010  /* [XSI] Any child stopped then continued */
#define WNOWAIT         0x00000020  /* [XSI] Leave process returned waitable */


#if (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
/* POSIX extensions and 4.2/4.3 compatability: */

/*
 * Tokens for special values of the "pid" parameter to wait4.
 */
#define WAIT_ANY        (-1)    /* any process */
#define WAIT_MYPGRP     0       /* any process in my process group */

#include <machine/endian.h>

/*
 * Deprecated:
 * Structure of the information in the status word returned by wait4.
 * If w_stopval==_WSTOPPED, then the second structure describes
 * the information returned, else the first.
 */
union wait {
	int     w_status;               /* used in syscall */
	/*
	 * Terminated process status.
	 */
	struct {
#if __DARWIN_BYTE_ORDER == __DARWIN_LITTLE_ENDIAN
		unsigned int    w_Termsig:7,    /* termination signal */
		    w_Coredump:1,               /* core dump indicator */
		    w_Retcode:8,                /* exit code if w_termsig==0 */
		    w_Filler:16;                /* upper bits filler */
#endif
#if __DARWIN_BYTE_ORDER == __DARWIN_BIG_ENDIAN
		unsigned int    w_Filler:16,    /* upper bits filler */
		    w_Retcode:8,                /* exit code if w_termsig==0 */
		    w_Coredump:1,               /* core dump indicator */
		    w_Termsig:7;                /* termination signal */
#endif
	} w_T;
	/*
	 * Stopped process status.  Returned
	 * only for traced children unless requested
	 * with the WUNTRACED option bit.
	 */
	struct {
#if __DARWIN_BYTE_ORDER == __DARWIN_LITTLE_ENDIAN
		unsigned int    w_Stopval:8,    /* == W_STOPPED if stopped */
		    w_Stopsig:8,                /* signal that stopped us */
		    w_Filler:16;                /* upper bits filler */
#endif
#if __DARWIN_BYTE_ORDER == __DARWIN_BIG_ENDIAN
		unsigned int    w_Filler:16,    /* upper bits filler */
		    w_Stopsig:8,                /* signal that stopped us */
		    w_Stopval:8;                /* == W_STOPPED if stopped */
#endif
	} w_S;
};
#define w_termsig       w_T.w_Termsig
#define w_coredump      w_T.w_Coredump
#define w_retcode       w_T.w_Retcode
#define w_stopval       w_S.w_Stopval
#define w_stopsig       w_S.w_Stopsig

#endif /* (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)) */

#if !(__DARWIN_UNIX03 - 0)
/*
 * Stopped state value; cannot use waitid() parameter of the same name
 * in the same scope
 */
#define WSTOPPED        _WSTOPPED
#endif /* !__DARWIN_UNIX03 */

__BEGIN_DECLS
pid_t   wait(int *) __DARWIN_ALIAS_C(wait);
pid_t   waitpid(pid_t, int *, int) __DARWIN_ALIAS_C(waitpid);
#ifndef _ANSI_SOURCE
int     waitid(idtype_t, id_t, siginfo_t *, int) __DARWIN_ALIAS_C(waitid);
#endif /* !_ANSI_SOURCE */
#if  (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
pid_t   wait3(int *, int, struct rusage *);
pid_t   wait4(pid_t, int *, int, struct rusage *);
#endif /* (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)) */
__END_DECLS
#endif /* !_SYS_WAIT_H_ */
