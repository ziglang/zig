/*
 * Copyright (c) 2004-2006 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*	$NetBSD: utmpx.h,v 1.11 2003/08/26 16:48:32 wiz Exp $	 */

/*-
 * Copyright (c) 2002 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Christos Zoulas.
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
 *        This product includes software developed by the NetBSD
 *        Foundation, Inc. and its contributors.
 * 4. Neither the name of The NetBSD Foundation nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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
#ifndef	_UTMPX_H_
#define	_UTMPX_H_

#include <_types.h>
#include <sys/time.h>
#include <sys/cdefs.h>
#include <Availability.h>
#include <sys/_types/_pid_t.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <sys/_types/_uid_t.h>
#endif /* !_POSIX_C_SOURCE || _DARWIN_C_SOURCE */

#define	_PATH_UTMPX		"/var/run/utmpx"

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define	UTMPX_FILE	_PATH_UTMPX
#endif /* !_POSIX_C_SOURCE || _DARWIN_C_SOURCE */

#define _UTX_USERSIZE	256	/* matches MAXLOGNAME */
#define _UTX_LINESIZE	32
#define	_UTX_IDSIZE	4
#define _UTX_HOSTSIZE	256

#define EMPTY		0
#define RUN_LVL		1
#define BOOT_TIME	2
#define OLD_TIME	3
#define NEW_TIME	4
#define INIT_PROCESS	5
#define LOGIN_PROCESS	6
#define USER_PROCESS	7
#define DEAD_PROCESS	8

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define ACCOUNTING	9
#define SIGNATURE	10
#define SHUTDOWN_TIME	11

#define UTMPX_AUTOFILL_MASK			0x8000
#define UTMPX_DEAD_IF_CORRESPONDING_MASK	0x4000

/* notify(3) change notification name */
#define UTMPX_CHANGE_NOTIFICATION		"com.apple.system.utmpx"
#endif /* !_POSIX_C_SOURCE || _DARWIN_C_SOURCE */

/*
 * The following structure describes the fields of the utmpx entries
 * stored in _PATH_UTMPX. This is not the format the
 * entries are stored in the files, and application should only access
 * entries using routines described in getutxent(3).
 */

#ifdef _UTMPX_COMPAT
#define ut_user ut_name
#define ut_xtime ut_tv.tv_sec
#endif /* _UTMPX_COMPAT */

struct utmpx {
	char ut_user[_UTX_USERSIZE];	/* login name */
	char ut_id[_UTX_IDSIZE];	/* id */
	char ut_line[_UTX_LINESIZE];	/* tty name */
	pid_t ut_pid;			/* process id creating the entry */
	short ut_type;			/* type of this entry */
	struct timeval ut_tv;		/* time entry was created */
	char ut_host[_UTX_HOSTSIZE];	/* host name */
	__uint32_t ut_pad[16];		/* reserved for future use */
};

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
struct lastlogx {
	struct timeval ll_tv;		/* time entry was created */
	char ll_line[_UTX_LINESIZE];	/* tty name */
	char ll_host[_UTX_HOSTSIZE];	/* host name */
};
#endif /* !_POSIX_C_SOURCE || _DARWIN_C_SOURCE */

__BEGIN_DECLS

void	endutxent(void);

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
void	endutxent_wtmp(void) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
struct lastlogx *
	getlastlogx(uid_t, struct lastlogx *) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
struct lastlogx *
	getlastlogxbyname(const char*, struct lastlogx *)__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
struct utmp;	/* forward reference */
void	getutmp(const struct utmpx *, struct utmp *) __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_5, __MAC_10_9, __IPHONE_2_0, __IPHONE_7_0) __WATCHOS_PROHIBITED __TVOS_PROHIBITED;
void	getutmpx(const struct utmp *, struct utmpx *) __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_5, __MAC_10_9, __IPHONE_2_0, __IPHONE_7_0) __WATCHOS_PROHIBITED __TVOS_PROHIBITED;
#endif /* !_POSIX_C_SOURCE || _DARWIN_C_SOURCE */

struct utmpx *
	getutxent(void);

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
struct utmpx *
	getutxent_wtmp(void) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
#endif /* !_POSIX_C_SOURCE || _DARWIN_C_SOURCE */

struct utmpx *
	getutxid(const struct utmpx *);
struct utmpx *
	getutxline(const struct utmpx *);
struct utmpx *
	pututxline(const struct utmpx *);
void	setutxent(void);

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
void	setutxent_wtmp(int) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int	utmpxname(const char *) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int	wtmpxname(const char *) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
#endif /* !_POSIX_C_SOURCE || _DARWIN_C_SOURCE */

__END_DECLS

#endif /* !_UTMPX_H_ */
