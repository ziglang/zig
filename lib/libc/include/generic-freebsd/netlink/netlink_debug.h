/*-
 * Copyright (c) 2022 Alexander V. Chernikov <melifaro@FreeBSD.org>
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

#ifndef _NETLINK_NETLINK_DEBUG_H_
#define	_NETLINK_NETLINK_DEBUG_H_

#ifdef _KERNEL

#define	_DEBUG_SYSCTL_OID	_net_netlink_debug
#include <net/route/route_debug.h>

SYSCTL_DECL(_net_netlink_debug);

/*
 * Generic debug
 * [nl_domain] func_name: debug text
 */
#define	NL_LOG	RT_LOG

/*
 * Logging for events specific for particular process
 * Example: [nl_domain] PID 4834 fdump_sa: unsupported family: 45
 */
#define	NL_RAW_PID_LOG(_l, _pid, _fmt, ...)		\
	NL_RAW_PID_LOG_##_l(_l, _pid, _fmt, ## __VA_ARGS__)
#define	_NL_RAW_PID_LOG(_l, _pid, _fmt, ...)		\
	if (_DEBUG_PASS_MSG(_l)) {			\
		_output("[" DEBUG_PREFIX_NAME "] PID %u %s: " _fmt "\n", _pid, \
		    __func__, ##__VA_ARGS__);		\
	}

#define	NLP_LOG(_l, _nlp, _fmt, ...)			\
	NL_RAW_PID_LOG_##_l(_l, nlp_get_pid(_nlp), _fmt, ## __VA_ARGS__)

#if DEBUG_MAX_LEVEL>=LOG_DEBUG3
#define	NL_RAW_PID_LOG_LOG_DEBUG3	_NL_RAW_PID_LOG
#else
#define	NL_RAW_PID_LOG_LOG_DEBUG3(_l, _pid, _fmt, ...)
#endif
#if DEBUG_MAX_LEVEL>=LOG_DEBUG2
#define	NL_RAW_PID_LOG_LOG_DEBUG2	_NL_RAW_PID_LOG
#else
#define	NL_RAW_PID_LOG_LOG_DEBUG2(_l, _pid, _fmt, ...)
#endif
#if DEBUG_MAX_LEVEL>=LOG_DEBUG
#define	NL_RAW_PID_LOG_LOG_DEBUG	_NL_RAW_PID_LOG
#else
#define	NL_RAW_PID_LOG_LOG_DEBUG(_l, _pid, _fmt, ...)
#endif
#if DEBUG_MAX_LEVEL>=LOG_INFO
#define	NL_RAW_PID_LOG_LOG_INFO	_NL_RAW_PID_LOG
#else
#define	NL_RAW_PID_LOG_LOG_INFO(_l, _pid, _fmt, ...)
#endif
#define	NL_RAW_PID_LOG_LOG_NOTICE	_NL_RAW_PID_LOG
#define	NL_RAW_PID_LOG_LOG_ERR         _NL_RAW_PID_LOG
#define	NL_RAW_PID_LOG_LOG_WARNING	_NL_RAW_PID_LOG

#endif	/* _KERNEL */
#endif	/* !_NETLINK_NETLINK_DEBUG_H_ */