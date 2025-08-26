/*-
 * Copyright (c) 2014 The FreeBSD Foundation
 *
 * This software was developed by Semihalf under
 * the sponsorship of the FreeBSD Foundation.
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _MACHINE_DEBUG_MONITOR_H_
#define	_MACHINE_DEBUG_MONITOR_H_

#define	DBG_BRP_MAX	16
#define	DBG_WRP_MAX	16

struct debug_monitor_state {
	uint32_t	dbg_enable_count;
	uint32_t	dbg_flags;
#define	DBGMON_ENABLED		(1 << 0)
#define	DBGMON_KERNEL		(1 << 1)
	uint64_t	dbg_bcr[DBG_BRP_MAX];
	uint64_t	dbg_bvr[DBG_BRP_MAX];
	uint64_t	dbg_wcr[DBG_WRP_MAX];
	uint64_t	dbg_wvr[DBG_WRP_MAX];
};

#ifdef _KERNEL

enum dbg_access_t {
	HW_BREAKPOINT_X		= 0,
	HW_BREAKPOINT_R		= 1,
	HW_BREAKPOINT_W		= 2,
	HW_BREAKPOINT_RW	= HW_BREAKPOINT_R | HW_BREAKPOINT_W,
};

void dbg_monitor_init(void);
void dbg_register_sync(struct debug_monitor_state *);

#ifdef DDB
void dbg_show_watchpoint(void);
#endif

#endif /* _KERNEL */

#endif /* _MACHINE_DEBUG_MONITOR_H_ */