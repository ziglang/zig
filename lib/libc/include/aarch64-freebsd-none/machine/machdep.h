/*-
 * Copyright (c) 2013 Andrew Turner <andrew@freebsd.org>
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

#ifndef _MACHINE_MACHDEP_H_
#define	_MACHINE_MACHDEP_H_

#ifdef _KERNEL

struct arm64_bootparams {
	vm_offset_t	modulep;
	vm_offset_t	kern_stack;
	vm_paddr_t	kern_ttbr0;
	uint64_t	hcr_el2;
	int		boot_el;	/* EL the kernel booted from */
	int		pad;
};

enum arm64_bus {
	ARM64_BUS_NONE,
	ARM64_BUS_FDT,
	ARM64_BUS_ACPI,
};

extern enum arm64_bus arm64_bus_method;

void dbg_init(void);
bool has_hyp(void);
void initarm(struct arm64_bootparams *);
vm_offset_t parse_boot_param(struct arm64_bootparams *abp);
#ifdef FDT
void parse_fdt_bootargs(void);
#endif
int memory_mapping_mode(vm_paddr_t pa);
extern void (*pagezero)(void *);

#ifdef SOCDEV_PA
/*
 * The virtual address SOCDEV_PA is mapped at.
 * Only valid while the early pagetables are valid.
 */
extern uintptr_t socdev_va;
#endif

#endif /* _KERNEL */

#endif /* _MACHINE_MACHDEP_H_ */