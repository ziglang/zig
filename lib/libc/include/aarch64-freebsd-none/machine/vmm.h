/*
 * Copyright (C) 2015 Mihai Carabas <mihai.carabas@gmail.com>
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
 * THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _VMM_H_
#define	_VMM_H_

#include <sys/param.h>
#include <sys/cpuset.h>
#include <vm/vm.h>
#include <vm/pmap.h>

#include "pte.h"
#include "pmap.h"

struct vcpu;

enum vm_suspend_how {
	VM_SUSPEND_NONE,
	VM_SUSPEND_RESET,
	VM_SUSPEND_POWEROFF,
	VM_SUSPEND_HALT,
	VM_SUSPEND_DESTROY,
	VM_SUSPEND_LAST
};

/*
 * Identifiers for architecturally defined registers.
 */
enum vm_reg_name {
	VM_REG_GUEST_X0 = 0,
	VM_REG_GUEST_X1,
	VM_REG_GUEST_X2,
	VM_REG_GUEST_X3,
	VM_REG_GUEST_X4,
	VM_REG_GUEST_X5,
	VM_REG_GUEST_X6,
	VM_REG_GUEST_X7,
	VM_REG_GUEST_X8,
	VM_REG_GUEST_X9,
	VM_REG_GUEST_X10,
	VM_REG_GUEST_X11,
	VM_REG_GUEST_X12,
	VM_REG_GUEST_X13,
	VM_REG_GUEST_X14,
	VM_REG_GUEST_X15,
	VM_REG_GUEST_X16,
	VM_REG_GUEST_X17,
	VM_REG_GUEST_X18,
	VM_REG_GUEST_X19,
	VM_REG_GUEST_X20,
	VM_REG_GUEST_X21,
	VM_REG_GUEST_X22,
	VM_REG_GUEST_X23,
	VM_REG_GUEST_X24,
	VM_REG_GUEST_X25,
	VM_REG_GUEST_X26,
	VM_REG_GUEST_X27,
	VM_REG_GUEST_X28,
	VM_REG_GUEST_X29,
	VM_REG_GUEST_LR,
	VM_REG_GUEST_SP,
	VM_REG_GUEST_PC,
	VM_REG_GUEST_CPSR,

	VM_REG_GUEST_SCTLR_EL1,
	VM_REG_GUEST_TTBR0_EL1,
	VM_REG_GUEST_TTBR1_EL1,
	VM_REG_GUEST_TCR_EL1,
	VM_REG_GUEST_TCR2_EL1,
	VM_REG_GUEST_MPIDR_EL1,
	VM_REG_LAST
};

#define	VM_INTINFO_VECTOR(info)	((info) & 0xff)
#define	VM_INTINFO_DEL_ERRCODE	0x800
#define	VM_INTINFO_RSVD		0x7ffff000
#define	VM_INTINFO_VALID	0x80000000
#define	VM_INTINFO_TYPE		0x700
#define	VM_INTINFO_HWINTR	(0 << 8)
#define	VM_INTINFO_NMI		(2 << 8)
#define	VM_INTINFO_HWEXCEPTION	(3 << 8)
#define	VM_INTINFO_SWINTR	(4 << 8)

#define VM_GUEST_BASE_IPA	0x80000000UL	/* Guest kernel start ipa */

/*
 * The VM name has to fit into the pathname length constraints of devfs,
 * governed primarily by SPECNAMELEN.  The length is the total number of
 * characters in the full path, relative to the mount point and not 
 * including any leading '/' characters.
 * A prefix and a suffix are added to the name specified by the user.
 * The prefix is usually "vmm/" or "vmm.io/", but can be a few characters
 * longer for future use.
 * The suffix is a string that identifies a bootrom image or some similar
 * image that is attached to the VM. A separator character gets added to
 * the suffix automatically when generating the full path, so it must be
 * accounted for, reducing the effective length by 1.
 * The effective length of a VM name is 229 bytes for FreeBSD 13 and 37
 * bytes for FreeBSD 12.  A minimum length is set for safety and supports
 * a SPECNAMELEN as small as 32 on old systems.
 */
#define VM_MAX_PREFIXLEN 10
#define VM_MAX_SUFFIXLEN 15
#define VM_MAX_NAMELEN \
    (SPECNAMELEN - VM_MAX_PREFIXLEN - VM_MAX_SUFFIXLEN - 1)

#ifdef _KERNEL
struct vm;
struct vm_exception;
struct vm_exit;
struct vm_run;
struct vm_object;
struct vm_guest_paging;
struct vm_vgic_descr;
struct pmap;

struct vm_eventinfo {
	void	*rptr;		/* rendezvous cookie */
	int	*sptr;		/* suspend cookie */
	int	*iptr;		/* reqidle cookie */
};

int vm_create(const char *name, struct vm **retvm);
struct vcpu *vm_alloc_vcpu(struct vm *vm, int vcpuid);
void vm_disable_vcpu_creation(struct vm *vm);
void vm_slock_vcpus(struct vm *vm);
void vm_unlock_vcpus(struct vm *vm);
void vm_destroy(struct vm *vm);
int vm_reinit(struct vm *vm);
const char *vm_name(struct vm *vm);

uint16_t vm_get_maxcpus(struct vm *vm);
void vm_get_topology(struct vm *vm, uint16_t *sockets, uint16_t *cores,
    uint16_t *threads, uint16_t *maxcpus);
int vm_set_topology(struct vm *vm, uint16_t sockets, uint16_t cores,
    uint16_t threads, uint16_t maxcpus);
int vm_get_register(struct vcpu *vcpu, int reg, uint64_t *retval);
int vm_set_register(struct vcpu *vcpu, int reg, uint64_t val);
int vm_run(struct vcpu *vcpu);
int vm_suspend(struct vm *vm, enum vm_suspend_how how);
void* vm_get_cookie(struct vm *vm);
int vcpu_vcpuid(struct vcpu *vcpu);
void *vcpu_get_cookie(struct vcpu *vcpu);
struct vm *vcpu_vm(struct vcpu *vcpu);
struct vcpu *vm_vcpu(struct vm *vm, int cpu);
int vm_get_capability(struct vcpu *vcpu, int type, int *val);
int vm_set_capability(struct vcpu *vcpu, int type, int val);
int vm_activate_cpu(struct vcpu *vcpu);
int vm_suspend_cpu(struct vm *vm, struct vcpu *vcpu);
int vm_resume_cpu(struct vm *vm, struct vcpu *vcpu);
int vm_inject_exception(struct vcpu *vcpu, uint64_t esr, uint64_t far);
int vm_attach_vgic(struct vm *vm, struct vm_vgic_descr *descr);
int vm_assert_irq(struct vm *vm, uint32_t irq);
int vm_deassert_irq(struct vm *vm, uint32_t irq);
int vm_raise_msi(struct vm *vm, uint64_t msg, uint64_t addr, int bus, int slot,
    int func);
struct vm_exit *vm_exitinfo(struct vcpu *vcpu);
void vm_exit_suspended(struct vcpu *vcpu, uint64_t pc);
void vm_exit_debug(struct vcpu *vcpu, uint64_t pc);
void vm_exit_rendezvous(struct vcpu *vcpu, uint64_t pc);
void vm_exit_astpending(struct vcpu *vcpu, uint64_t pc);

cpuset_t vm_active_cpus(struct vm *vm);
cpuset_t vm_debug_cpus(struct vm *vm);
cpuset_t vm_suspended_cpus(struct vm *vm);

static __inline int
vcpu_rendezvous_pending(struct vm_eventinfo *info)
{

	return (*((uintptr_t *)(info->rptr)) != 0);
}

static __inline int
vcpu_suspended(struct vm_eventinfo *info)
{

	return (*info->sptr);
}

int vcpu_debugged(struct vcpu *vcpu);

enum vcpu_state {
	VCPU_IDLE,
	VCPU_FROZEN,
	VCPU_RUNNING,
	VCPU_SLEEPING,
};

int vcpu_set_state(struct vcpu *vcpu, enum vcpu_state state, bool from_idle);
enum vcpu_state vcpu_get_state(struct vcpu *vcpu, int *hostcpu);

static int __inline
vcpu_is_running(struct vcpu *vcpu, int *hostcpu)
{
	return (vcpu_get_state(vcpu, hostcpu) == VCPU_RUNNING);
}

#ifdef _SYS_PROC_H_
static int __inline
vcpu_should_yield(struct vcpu *vcpu)
{
	struct thread *td;

	td = curthread;
	return (td->td_ast != 0 || td->td_owepreempt != 0);
}
#endif

void *vcpu_stats(struct vcpu *vcpu);
void vcpu_notify_event(struct vcpu *vcpu);
struct vmspace *vm_vmspace(struct vm *vm);
struct vm_mem *vm_mem(struct vm *vm);

enum vm_reg_name vm_segment_name(int seg_encoding);

struct vm_copyinfo {
	uint64_t	gpa;
	size_t		len;
	void		*hva;
	void		*cookie;
};

#endif	/* _KERNEL */

#define	VM_DIR_READ	0
#define	VM_DIR_WRITE	1

#define	VM_GP_M_MASK		0x1f
#define	VM_GP_MMU_ENABLED	(1 << 5)

struct vm_guest_paging {
	uint64_t	ttbr0_addr;
	uint64_t	ttbr1_addr;
	uint64_t	tcr_el1;
	uint64_t	tcr2_el1;
	int		flags;
	int		padding;
};

struct vie {
	uint8_t access_size:4, sign_extend:1, dir:1, unused:2;
	enum vm_reg_name reg;
};

struct vre {
	uint32_t inst_syndrome;
	uint8_t dir:1, unused:7;
	enum vm_reg_name reg;
};

/*
 * Identifiers for optional vmm capabilities
 */
enum vm_cap_type {
	VM_CAP_HALT_EXIT,
	VM_CAP_PAUSE_EXIT,
	VM_CAP_UNRESTRICTED_GUEST,
	VM_CAP_BRK_EXIT,
	VM_CAP_SS_EXIT,
	VM_CAP_MASK_HWINTR,
	VM_CAP_MAX
};

enum vm_exitcode {
	VM_EXITCODE_BOGUS,
	VM_EXITCODE_INST_EMUL,
	VM_EXITCODE_REG_EMUL,
	VM_EXITCODE_HVC,
	VM_EXITCODE_SUSPENDED,
	VM_EXITCODE_HYP,
	VM_EXITCODE_WFI,
	VM_EXITCODE_PAGING,
	VM_EXITCODE_SMCCC,
	VM_EXITCODE_DEBUG,
	VM_EXITCODE_BRK,
	VM_EXITCODE_SS,
	VM_EXITCODE_MAX
};

struct vm_exit {
	enum vm_exitcode	exitcode;
	int			inst_length;
	uint64_t		pc;
	union {
		/*
		 * ARM specific payload.
		 */
		struct {
			uint32_t	exception_nr;
			uint32_t	pad;
			uint64_t	esr_el2;	/* Exception Syndrome Register */
			uint64_t	far_el2;	/* Fault Address Register */
			uint64_t	hpfar_el2;	/* Hypervisor IPA Fault Address Register */
		} hyp;
		struct {
			struct vre 	vre;
		} reg_emul;
		struct {
			uint64_t	gpa;
			uint64_t	esr;
		} paging;
		struct {
			uint64_t	gpa;
			struct vm_guest_paging paging;
			struct vie	vie;
		} inst_emul;

		/*
		 * A SMCCC call, e.g. starting a core via PSCI.
		 * Further arguments can be read by asking the kernel for
		 * all register values.
		 */
		struct {
			uint64_t	func_id;
			uint64_t	args[7];
		} smccc_call;

		struct {
			enum vm_suspend_how how;
		} suspended;
	} u;
};

#endif	/* _VMM_H_ */