/*-
 * Copyright (c) 2021 The FreeBSD Foundation
 *
 * This software were developed by Konstantin Belousov <kib@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
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

#ifndef __SYS_MEMBARRIER_H__
#define	__SYS_MEMBARRIER_H__

#include <sys/cdefs.h>

/*
 * The enum membarrier_cmd values are bits.  The MEMBARRIER_CMD_QUERY
 * command returns a bitset indicating which commands are supported.
 * Also the value of MEMBARRIER_CMD_QUERY is zero, so it is
 * effectively not returned by the query.
 */
enum membarrier_cmd {
	MEMBARRIER_CMD_QUERY =				0x00000000,
	MEMBARRIER_CMD_GLOBAL =				0x00000001,
	MEMBARRIER_CMD_SHARED =				MEMBARRIER_CMD_GLOBAL,
	MEMBARRIER_CMD_GLOBAL_EXPEDITED =		0x00000002,
	MEMBARRIER_CMD_REGISTER_GLOBAL_EXPEDITED =	0x00000004,
	MEMBARRIER_CMD_PRIVATE_EXPEDITED =		0x00000008,
	MEMBARRIER_CMD_REGISTER_PRIVATE_EXPEDITED =	0x00000010,
	MEMBARRIER_CMD_PRIVATE_EXPEDITED_SYNC_CORE =	0x00000020,
	MEMBARRIER_CMD_REGISTER_PRIVATE_EXPEDITED_SYNC_CORE =	0x00000040,

	/*
	 * RSEQ constants are defined for source compatibility but are
	 * not yet supported, MEMBARRIER_CMD_QUERY does not return
	 * them in the mask.
	 */
	MEMBARRIER_CMD_PRIVATE_EXPEDITED_RSEQ =		0x00000080,
	MEMBARRIER_CMD_REGISTER_PRIVATE_EXPEDITED_RSEQ = 0x00000100,
};

enum membarrier_cmd_flag {
	MEMBARRIER_CMD_FLAG_CPU =			0x00000001,
};

#ifndef _KERNEL
__BEGIN_DECLS
int membarrier(int, unsigned, int);
__END_DECLS
#endif	/* _KERNEL */

#endif /* __SYS_MEMBARRIER_H__ */