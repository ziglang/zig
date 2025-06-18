/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 1999 Michael Smith <msmith@freebsd.org>
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS__EVENTHANDLER_H_
#define _SYS__EVENTHANDLER_H_

#include <sys/queue.h>

struct eventhandler_entry {
	TAILQ_ENTRY(eventhandler_entry)	ee_link;
	int				ee_priority;
#define	EHE_DEAD_PRIORITY	(-1)
	void				*ee_arg;
};

typedef struct eventhandler_entry	*eventhandler_tag;

/*
 * You can optionally use the EVENTHANDLER_LIST and EVENTHANDLER_DIRECT macros
 * to pre-define a symbol for the eventhandler list. This symbol can be used by
 * EVENTHANDLER_DIRECT_INVOKE, which has the advantage of not needing to do a
 * locked search of the global list of eventhandler lists. At least
 * EVENTHANDLER_LIST_DEFINE must be used for EVENTHANDLER_DIRECT_INVOKE to
 * work. EVENTHANDLER_LIST_DECLARE is only needed if the call to
 * EVENTHANDLER_DIRECT_INVOKE is in a different compilation unit from
 * EVENTHANDLER_LIST_DEFINE. If the events are even relatively high frequency
 * it is suggested that you directly define a list for them.
 */
struct eventhandler_list;
#define	EVENTHANDLER_LIST_DECLARE(name)					\
extern struct eventhandler_list *_eventhandler_list_ ## name		\

/*
 * Event handlers need to be declared, but do not need to be defined. The
 * declaration must be in scope wherever the handler is to be invoked.
 */
#define EVENTHANDLER_DECLARE(name, type)				\
struct eventhandler_entry_ ## name 					\
{									\
	struct eventhandler_entry	ee;				\
	type				eh_func;			\
};									\
struct __hack

#endif