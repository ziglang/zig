/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2008-2022 NetApp, Inc.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_BOOTTRACE_H_
#define	_SYS_BOOTTRACE_H_

#define	_BOOTTRACE_BOOTTRACE	"kern.boottrace.boottrace"
#define	_BOOTTRACE_RUNTRACE	"kern.boottrace.runtrace"
#define	_BOOTTRACE_SHUTTRACE	"kern.boottrace.shuttrace"

/* Messages are formatted as 'tdname:name' */
#define	BT_EVENT_TDNAMELEN	24
#define	BT_EVENT_NAMELEN	40
#define	BT_MSGLEN		(BT_EVENT_NAMELEN + 1 + BT_EVENT_TDNAMELEN)

#ifndef _KERNEL
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/sysctl.h>

/*
 * Convenience macros. Userland API.
 */
#define	BOOTTRACE(...)		_boottrace(_BOOTTRACE_BOOTTRACE, __VA_ARGS__)
#define	RUNTRACE(...)		_boottrace(_BOOTTRACE_RUNTRACE, __VA_ARGS__)
#define	SHUTTRACE(...)		_boottrace(_BOOTTRACE_SHUTTRACE, __VA_ARGS__)

/*
 * Call the requested boottrace sysctl with provided va-formatted message.
 */
static __inline void
_boottrace(const char *sysctlname, const char *fmt, ...)
{
	va_list ap;
	char msg[BT_MSGLEN];
	int len;

	va_start(ap, fmt);
	len = vsnprintf(msg, sizeof(msg), fmt, ap);
	va_end(ap);

	/* Log the event, even if truncated. */
	if (len >= 0)
		(void)sysctlbyname(sysctlname, NULL, NULL, msg, strlen(msg));
}

#else /* _KERNEL */

/*
 * Convenience macros. Kernel API.
 */
#define	_BOOTTRACE(tdname, ...) do {					\
		if (boottrace_enabled)					\
			(void)boottrace(tdname, __VA_ARGS__);		\
	} while (0)
#define	BOOTTRACE(...)		_BOOTTRACE(NULL, __VA_ARGS__)
#define	BOOTTRACE_INIT(...)	_BOOTTRACE("kernel", __VA_ARGS__)

extern bool boottrace_enabled;
extern bool shutdown_trace;

int  boottrace(const char *_tdname, const char *_eventfmt, ...)
    __printflike(2,3);
void boottrace_reset(const char *_actor);
int  boottrace_resize(u_int _newsize);
void boottrace_dump_console(void);

#endif /* _KERNEL */
#endif /* _SYS_BOOTTRACE_H_ */