/*-
 * Copyright (c) 2016 Ruslan Bukin <br@bsdpad.com>
 * All rights reserved.
 *
 * Portions of this software were developed by SRI International and the
 * University of Cambridge Computer Laboratory under DARPA/AFRL contract
 * FA8750-10-C-0237 ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * Portions of this software were developed by the University of Cambridge
 * Computer Laboratory as part of the CTSRD Project, with support from the
 * UK Higher Education Innovation Fund (HEIF).
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

#ifndef _MACHINE_STACK_H_
#define	_MACHINE_STACK_H_

#define	INKERNEL(va)	((va) >= VM_MIN_KERNEL_ADDRESS && \
			 (va) <= VM_MAX_KERNEL_ADDRESS)

struct unwind_state {
	uintptr_t fp;
	uintptr_t sp;
	uintptr_t pc;
};

bool unwind_frame(struct thread *, struct unwind_state *);

#ifdef _SYS_PROC_H_

#include <machine/pcb.h>

/* Get the current kernel thread stack usage. */
#define	GET_STACK_USAGE(total, used) do {				\
	struct thread *td = curthread;					\
	(total) = td->td_kstack_pages * PAGE_SIZE - sizeof(struct pcb);	\
	(used) = td->td_kstack + (total) - (vm_offset_t)&td;		\
} while (0)

static __inline bool
kstack_contains(struct thread *td, vm_offset_t va, size_t len)
{
	return (va >= td->td_kstack && va + len >= va &&
	    va + len <= td->td_kstack + td->td_kstack_pages * PAGE_SIZE -
	    sizeof(struct pcb));
}
#endif	/* _SYS_PROC_H_ */

#endif /* !_MACHINE_STACK_H_ */