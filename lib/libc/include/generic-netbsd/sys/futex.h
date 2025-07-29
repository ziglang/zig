/*	$NetBSD: futex.h,v 1.5 2021/09/28 15:05:42 thorpej Exp $	*/

/*-
 * Copyright (c) 2018, 2019 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Taylor R. Campbell and Jason R. Thorpe.
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

/*-
 * Copyright (c) 2005 Emmanuel Dreyfus, all rights reserved.
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
 *	This product includes software developed by Emmanuel Dreyfus
 * 4. The name of the author may not be used to endorse or promote 
 *    products derived from this software without specific prior written 
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE THE AUTHOR AND CONTRIBUTORS ``AS IS'' 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS 
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_FUTEX_H_
#define _SYS_FUTEX_H_

/*
 * Definitions for the __futex(2) synchronization primitive.
 *
 * These definitions are intended to be ABI-compatible with the
 * Linux futex(2) system call.
 */

#include <sys/timespec.h>

#define FUTEX_WAIT			  0 
#define FUTEX_WAKE			  1
#define FUTEX_FD			  2
#define FUTEX_REQUEUE			  3
#define FUTEX_CMP_REQUEUE		  4
#define FUTEX_WAKE_OP			  5
#define FUTEX_LOCK_PI			  6
#define FUTEX_UNLOCK_PI			  7
#define FUTEX_TRYLOCK_PI		  8
#define FUTEX_WAIT_BITSET		  9
#define FUTEX_WAKE_BITSET		 10
#define FUTEX_WAIT_REQUEUE_PI		 11
#define FUTEX_CMP_REQUEUE_PI		 12

#define FUTEX_PRIVATE_FLAG		__BIT(7)
#define FUTEX_CLOCK_REALTIME		__BIT(8)

#define FUTEX_CMD_MASK			\
    (~(FUTEX_PRIVATE_FLAG|FUTEX_CLOCK_REALTIME))

#define FUTEX_OP_OP_MASK		__BITS(28,31)
#define FUTEX_OP_CMP_MASK		__BITS(24,27)
#define FUTEX_OP_OPARG_MASK		__BITS(12,23)
#define FUTEX_OP_CMPARG_MASK		__BITS(0,11)

#define FUTEX_OP(op, oparg, cmp, cmparg)		 \
	(__SHIFTIN(op, FUTEX_OP_OP_MASK)		|\
	 __SHIFTIN(oparg, FUTEX_OP_OPARG_MASK)		|\
	 __SHIFTIN(cmp, FUTEX_OP_CMP_MASK)		|\
	 __SHIFTIN(cmparg, FUTEX_OP_CMPARG_MASK))

#define FUTEX_OP_SET		0
#define FUTEX_OP_ADD		1
#define FUTEX_OP_OR		2
#define FUTEX_OP_ANDN		3
#define FUTEX_OP_XOR		4
#define FUTEX_OP_OPARG_SHIFT	8

#define FUTEX_OP_CMP_EQ		0
#define FUTEX_OP_CMP_NE		1
#define FUTEX_OP_CMP_LT		2
#define FUTEX_OP_CMP_LE		3
#define FUTEX_OP_CMP_GT		4
#define FUTEX_OP_CMP_GE		5

/*
 * FUTEX_SYNCOBJ_0 and FUTEX_SYNCOBJ_1 are extensions to the Linux
 * futex API that are reserved for individual consumers of futexes
 * to define information specific to that synchronzation object.
 * Note that as a result there is a system-wide upper limit of
 * 268,435,455 threads (as opposed to 1,073,741,823).
 */
#define FUTEX_WAITERS		((int)__BIT(31))
#define FUTEX_OWNER_DIED	((int)__BIT(30))
#define FUTEX_SYNCOBJ_1		((int)__BIT(29))
#define FUTEX_SYNCOBJ_0		((int)__BIT(28))
#define FUTEX_TID_MASK		((int)__BITS(0,27))

#define FUTEX_BITSET_MATCH_ANY  ((int)__BITS(0,31))

/*
 * The robust futex ABI consists of an array of 3 longwords, the address
 * of which is registered with the kernel on a per-thread basis:
 *
 *	0: A pointer to a singly-linked list of "lock entries".  If the
 *	   list is empty, this points back to the list itself.
 *
 *	1: An offset from address of the "lock entry" to the 32-bit futex
 *	   word associated with that lock entry (may be negative).
 *
 *	2: A "pending" pointer, for locks that are in the process of being
 *	   acquired or released.
 *
 * PI futexes are handled slightly differently.  User-space indicates
 * an entry is for a PI futex by setting the last-significant bit.
 */
#define _FUTEX_ROBUST_HEAD_LIST		0
#define _FUTEX_ROBUST_HEAD_OFFSET	1
#define _FUTEX_ROBUST_HEAD_PENDING	2
#define _FUTEX_ROBUST_HEAD_NWORDS	3
#define _FUTEX_ROBUST_HEAD_SIZE		(_FUTEX_ROBUST_HEAD_NWORDS * \
					 sizeof(u_long))
#define _FUTEX_ROBUST_HEAD_SIZE32	(_FUTEX_ROBUST_HEAD_NWORDS * \
					 sizeof(uint32_t))
#define	_FUTEX_ROBUST_ENTRY_PI		__BIT(0)

#ifdef __LIBC_FUTEX_PRIVATE
struct futex_robust_list {
	struct futex_robust_list	*next;
};

struct futex_robust_list_head {
	struct futex_robust_list	list;
	long				futex_offset;
	struct futex_robust_list	*pending_list;
};
#endif /* __LIBC_FUTEX_PRIVATE */

#ifdef _KERNEL
struct lwp;

int	futex_robust_head_lookup(struct lwp *, lwpid_t, void **);
void	futex_release_all_lwp(struct lwp *);
int	do_futex(int *, int, int, const struct timespec *, int *, int,
	    int, register_t *);
void	futex_sys_init(void);
void	futex_sys_fini(void);
#endif /* _KERNEL */

#endif /* ! _SYS_FUTEX_H_ */