/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1995 Bruce D. Evans.
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
 * 3. Neither the name of the author nor the names of contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
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

#ifdef __i386__
#include <i386/md_var.h>
#else /* !__i386__ */

#ifndef _MACHINE_MD_VAR_H_
#define	_MACHINE_MD_VAR_H_

#include <x86/x86_var.h>

extern char	ctx_switch_xsave[];
extern char	ctx_switch_xsave32[];
extern int	hw_lower_amd64_sharedpage;
extern int	hw_ibrs_disable;
extern int	hw_ssb_disable;
extern int	nmi_flush_l1d_sw;
extern int	syscall_ret_l1d_flush_mode;

extern vm_paddr_t intel_graphics_stolen_base;
extern vm_paddr_t intel_graphics_stolen_size;

extern int la57;

extern vm_paddr_t kernphys;
extern vm_paddr_t KERNend;

extern bool efi_boot;

struct	__mcontext;
struct	savefpu;
struct	sysentvec;

void	amd64_conf_fast_syscall(void);
void	amd64_db_resume_dbreg(void);
vm_paddr_t amd64_loadaddr(void);
void	amd64_lower_shared_page(struct sysentvec *);
void	amd64_bsp_pcpu_init1(struct pcpu *pc);
void	amd64_bsp_pcpu_init2(uint64_t rsp0);
void	amd64_bsp_ist_init(struct pcpu *pc);
void	amd64_syscall(struct thread *td, int traced);
void	amd64_syscall_ret_flush_l1d(int error);
void	amd64_syscall_ret_flush_l1d_recalc(void);
void	cpu_init_small_core(void);
void	doreti_iret(void) __asm(__STRING(doreti_iret));
void	doreti_iret_fault(void) __asm(__STRING(doreti_iret_fault));
void	flush_l1d_sw_abi(void);
void	ld_ds(void) __asm(__STRING(ld_ds));
void	ld_es(void) __asm(__STRING(ld_es));
void	ld_fs(void) __asm(__STRING(ld_fs));
void	ld_gs(void) __asm(__STRING(ld_gs));
void	ld_fsbase(void) __asm(__STRING(ld_fsbase));
void	ld_gsbase(void) __asm(__STRING(ld_gsbase));
void	ds_load_fault(void) __asm(__STRING(ds_load_fault));
void	es_load_fault(void) __asm(__STRING(es_load_fault));
void	fs_load_fault(void) __asm(__STRING(fs_load_fault));
void	gs_load_fault(void) __asm(__STRING(gs_load_fault));
void	fsbase_load_fault(void) __asm(__STRING(fsbase_load_fault));
void	gsbase_load_fault(void) __asm(__STRING(gsbase_load_fault));
void	fpstate_drop(struct thread *td);
void	pagezero(void *addr);
void	setidt(int idx, alias_for_inthand_t *func, int typ, int dpl, int ist);
void	set_top_of_stack_td(struct thread *td);
struct savefpu *get_pcb_user_save_td(struct thread *td);
struct savefpu *get_pcb_user_save_pcb(struct pcb *pcb);
void	pci_early_quirks(void);
void	get_fpcontext(struct thread *td, struct __mcontext *mcp,
	    char **xfpusave, size_t *xfpusave_len);
int	set_fpcontext(struct thread *td, struct __mcontext *mcp,
	    char *xfpustate, size_t xfpustate_len);

#endif /* !_MACHINE_MD_VAR_H_ */

#endif /* __i386__ */