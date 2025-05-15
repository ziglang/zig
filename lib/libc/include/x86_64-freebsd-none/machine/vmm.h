/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2011 NetApp, Inc.
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
 * THIS SOFTWARE IS PROVIDED BY NETAPP, INC ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL NETAPP, INC OR CONTRIBUTORS BE LIABLE
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

#include <sys/cpuset.h>
#include <sys/sdt.h>
#include <x86/segments.h>

struct vcpu;
struct vm_snapshot_meta;

#ifdef _KERNEL
SDT_PROVIDER_DECLARE(vmm);
#endif

enum vm_suspend_how {
	VM_SUSPEND_NONE,
	VM_SUSPEND_RESET,
	VM_SUSPEND_POWEROFF,
	VM_SUSPEND_HALT,
	VM_SUSPEND_TRIPLEFAULT,
	VM_SUSPEND_LAST
};

/*
 * Identifiers for architecturally defined registers.
 */
enum vm_reg_name {
	VM_REG_GUEST_RAX,
	VM_REG_GUEST_RBX,
	VM_REG_GUEST_RCX,
	VM_REG_GUEST_RDX,
	VM_REG_GUEST_RSI,
	VM_REG_GUEST_RDI,
	VM_REG_GUEST_RBP,
	VM_REG_GUEST_R8,
	VM_REG_GUEST_R9,
	VM_REG_GUEST_R10,
	VM_REG_GUEST_R11,
	VM_REG_GUEST_R12,
	VM_REG_GUEST_R13,
	VM_REG_GUEST_R14,
	VM_REG_GUEST_R15,
	VM_REG_GUEST_CR0,
	VM_REG_GUEST_CR3,
	VM_REG_GUEST_CR4,
	VM_REG_GUEST_DR7,
	VM_REG_GUEST_RSP,
	VM_REG_GUEST_RIP,
	VM_REG_GUEST_RFLAGS,
	VM_REG_GUEST_ES,
	VM_REG_GUEST_CS,
	VM_REG_GUEST_SS,
	VM_REG_GUEST_DS,
	VM_REG_GUEST_FS,
	VM_REG_GUEST_GS,
	VM_REG_GUEST_LDTR,
	VM_REG_GUEST_TR,
	VM_REG_GUEST_IDTR,
	VM_REG_GUEST_GDTR,
	VM_REG_GUEST_EFER,
	VM_REG_GUEST_CR2,
	VM_REG_GUEST_PDPTE0,
	VM_REG_GUEST_PDPTE1,
	VM_REG_GUEST_PDPTE2,
	VM_REG_GUEST_PDPTE3,
	VM_REG_GUEST_INTR_SHADOW,
	VM_REG_GUEST_DR0,
	VM_REG_GUEST_DR1,
	VM_REG_GUEST_DR2,
	VM_REG_GUEST_DR3,
	VM_REG_GUEST_DR6,
	VM_REG_GUEST_ENTRY_INST_LENGTH,
	VM_REG_GUEST_FS_BASE,
	VM_REG_GUEST_GS_BASE,
	VM_REG_GUEST_KGS_BASE,
	VM_REG_GUEST_TPR,
	VM_REG_LAST
};

enum x2apic_state {
	X2APIC_DISABLED,
	X2APIC_ENABLED,
	X2APIC_STATE_LAST
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
#define VM_MIN_NAMELEN   6
#define VM_MAX_NAMELEN \
    (SPECNAMELEN - VM_MAX_PREFIXLEN - VM_MAX_SUFFIXLEN - 1)

#ifdef _KERNEL
#include <sys/kassert.h>

CTASSERT(VM_MAX_NAMELEN >= VM_MIN_NAMELEN);

struct vm;
struct vm_exception;
struct seg_desc;
struct vm_exit;
struct vm_run;
struct vhpet;
struct vioapic;
struct vlapic;
struct vmspace;
struct vm_object;
struct vm_guest_paging;
struct pmap;
enum snapshot_req;

struct vm_eventinfo {
	cpuset_t *rptr;		/* rendezvous cookie */
	int	*sptr;		/* suspend cookie */
	int	*iptr;		/* reqidle cookie */
};

typedef int	(*vmm_init_func_t)(int ipinum);
typedef int	(*vmm_cleanup_func_t)(void);
typedef void	(*vmm_resume_func_t)(void);
typedef void *	(*vmi_init_func_t)(struct vm *vm, struct pmap *pmap);
typedef int	(*vmi_run_func_t)(void *vcpui, register_t rip,
		    struct pmap *pmap, struct vm_eventinfo *info);
typedef void	(*vmi_cleanup_func_t)(void *vmi);
typedef void *	(*vmi_vcpu_init_func_t)(void *vmi, struct vcpu *vcpu,
		    int vcpu_id);
typedef void	(*vmi_vcpu_cleanup_func_t)(void *vcpui);
typedef int	(*vmi_get_register_t)(void *vcpui, int num, uint64_t *retval);
typedef int	(*vmi_set_register_t)(void *vcpui, int num, uint64_t val);
typedef int	(*vmi_get_desc_t)(void *vcpui, int num, struct seg_desc *desc);
typedef int	(*vmi_set_desc_t)(void *vcpui, int num, struct seg_desc *desc);
typedef int	(*vmi_get_cap_t)(void *vcpui, int num, int *retval);
typedef int	(*vmi_set_cap_t)(void *vcpui, int num, int val);
typedef struct vmspace * (*vmi_vmspace_alloc)(vm_offset_t min, vm_offset_t max);
typedef void	(*vmi_vmspace_free)(struct vmspace *vmspace);
typedef struct vlapic * (*vmi_vlapic_init)(void *vcpui);
typedef void	(*vmi_vlapic_cleanup)(struct vlapic *vlapic);
typedef int	(*vmi_snapshot_vcpu_t)(void *vcpui, struct vm_snapshot_meta *meta);
typedef int	(*vmi_restore_tsc_t)(void *vcpui, uint64_t now);

struct vmm_ops {
	vmm_init_func_t		modinit;	/* module wide initialization */
	vmm_cleanup_func_t	modcleanup;
	vmm_resume_func_t	modresume;

	vmi_init_func_t		init;		/* vm-specific initialization */
	vmi_run_func_t		run;
	vmi_cleanup_func_t	cleanup;
	vmi_vcpu_init_func_t	vcpu_init;
	vmi_vcpu_cleanup_func_t	vcpu_cleanup;
	vmi_get_register_t	getreg;
	vmi_set_register_t	setreg;
	vmi_get_desc_t		getdesc;
	vmi_set_desc_t		setdesc;
	vmi_get_cap_t		getcap;
	vmi_set_cap_t		setcap;
	vmi_vmspace_alloc	vmspace_alloc;
	vmi_vmspace_free	vmspace_free;
	vmi_vlapic_init		vlapic_init;
	vmi_vlapic_cleanup	vlapic_cleanup;

	/* checkpoint operations */
	vmi_snapshot_vcpu_t	vcpu_snapshot;
	vmi_restore_tsc_t	restore_tsc;
};

extern const struct vmm_ops vmm_ops_intel;
extern const struct vmm_ops vmm_ops_amd;

extern u_int vm_maxcpu;			/* maximum virtual cpus */

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

/*
 * APIs that modify the guest memory map require all vcpus to be frozen.
 */
void vm_slock_memsegs(struct vm *vm);
void vm_xlock_memsegs(struct vm *vm);
void vm_unlock_memsegs(struct vm *vm);
int vm_mmap_memseg(struct vm *vm, vm_paddr_t gpa, int segid, vm_ooffset_t off,
    size_t len, int prot, int flags);
int vm_munmap_memseg(struct vm *vm, vm_paddr_t gpa, size_t len);
int vm_alloc_memseg(struct vm *vm, int ident, size_t len, bool sysmem);
void vm_free_memseg(struct vm *vm, int ident);
int vm_map_mmio(struct vm *vm, vm_paddr_t gpa, size_t len, vm_paddr_t hpa);
int vm_unmap_mmio(struct vm *vm, vm_paddr_t gpa, size_t len);
int vm_assign_pptdev(struct vm *vm, int bus, int slot, int func);
int vm_unassign_pptdev(struct vm *vm, int bus, int slot, int func);

/*
 * APIs that inspect the guest memory map require only a *single* vcpu to
 * be frozen. This acts like a read lock on the guest memory map since any
 * modification requires *all* vcpus to be frozen.
 */
int vm_mmap_getnext(struct vm *vm, vm_paddr_t *gpa, int *segid,
    vm_ooffset_t *segoff, size_t *len, int *prot, int *flags);
int vm_get_memseg(struct vm *vm, int ident, size_t *len, bool *sysmem,
    struct vm_object **objptr);
vm_paddr_t vmm_sysmem_maxaddr(struct vm *vm);
void *vm_gpa_hold(struct vcpu *vcpu, vm_paddr_t gpa, size_t len,
    int prot, void **cookie);
void *vm_gpa_hold_global(struct vm *vm, vm_paddr_t gpa, size_t len,
    int prot, void **cookie);
void vm_gpa_release(void *cookie);
bool vm_mem_allocated(struct vcpu *vcpu, vm_paddr_t gpa);

int vm_get_register(struct vcpu *vcpu, int reg, uint64_t *retval);
int vm_set_register(struct vcpu *vcpu, int reg, uint64_t val);
int vm_get_seg_desc(struct vcpu *vcpu, int reg,
		    struct seg_desc *ret_desc);
int vm_set_seg_desc(struct vcpu *vcpu, int reg,
		    struct seg_desc *desc);
int vm_run(struct vcpu *vcpu);
int vm_suspend(struct vm *vm, enum vm_suspend_how how);
int vm_inject_nmi(struct vcpu *vcpu);
int vm_nmi_pending(struct vcpu *vcpu);
void vm_nmi_clear(struct vcpu *vcpu);
int vm_inject_extint(struct vcpu *vcpu);
int vm_extint_pending(struct vcpu *vcpu);
void vm_extint_clear(struct vcpu *vcpu);
int vcpu_vcpuid(struct vcpu *vcpu);
struct vm *vcpu_vm(struct vcpu *vcpu);
struct vcpu *vm_vcpu(struct vm *vm, int cpu);
struct vlapic *vm_lapic(struct vcpu *vcpu);
struct vioapic *vm_ioapic(struct vm *vm);
struct vhpet *vm_hpet(struct vm *vm);
int vm_get_capability(struct vcpu *vcpu, int type, int *val);
int vm_set_capability(struct vcpu *vcpu, int type, int val);
int vm_get_x2apic_state(struct vcpu *vcpu, enum x2apic_state *state);
int vm_set_x2apic_state(struct vcpu *vcpu, enum x2apic_state state);
int vm_apicid2vcpuid(struct vm *vm, int apicid);
int vm_activate_cpu(struct vcpu *vcpu);
int vm_suspend_cpu(struct vm *vm, struct vcpu *vcpu);
int vm_resume_cpu(struct vm *vm, struct vcpu *vcpu);
int vm_restart_instruction(struct vcpu *vcpu);
struct vm_exit *vm_exitinfo(struct vcpu *vcpu);
cpuset_t *vm_exitinfo_cpuset(struct vcpu *vcpu);
void vm_exit_suspended(struct vcpu *vcpu, uint64_t rip);
void vm_exit_debug(struct vcpu *vcpu, uint64_t rip);
void vm_exit_rendezvous(struct vcpu *vcpu, uint64_t rip);
void vm_exit_astpending(struct vcpu *vcpu, uint64_t rip);
void vm_exit_reqidle(struct vcpu *vcpu, uint64_t rip);
int vm_snapshot_req(struct vm *vm, struct vm_snapshot_meta *meta);
int vm_restore_time(struct vm *vm);

#ifdef _SYS__CPUSET_H_
/*
 * Rendezvous all vcpus specified in 'dest' and execute 'func(arg)'.
 * The rendezvous 'func(arg)' is not allowed to do anything that will
 * cause the thread to be put to sleep.
 *
 * The caller cannot hold any locks when initiating the rendezvous.
 *
 * The implementation of this API may cause vcpus other than those specified
 * by 'dest' to be stalled. The caller should not rely on any vcpus making
 * forward progress when the rendezvous is in progress.
 */
typedef void (*vm_rendezvous_func_t)(struct vcpu *vcpu, void *arg);
int vm_smp_rendezvous(struct vcpu *vcpu, cpuset_t dest,
    vm_rendezvous_func_t func, void *arg);

cpuset_t vm_active_cpus(struct vm *vm);
cpuset_t vm_debug_cpus(struct vm *vm);
cpuset_t vm_suspended_cpus(struct vm *vm);
cpuset_t vm_start_cpus(struct vm *vm, const cpuset_t *tostart);
void vm_await_start(struct vm *vm, const cpuset_t *waiting);
#endif	/* _SYS__CPUSET_H_ */

static __inline int
vcpu_rendezvous_pending(struct vcpu *vcpu, struct vm_eventinfo *info)
{
	/*
	 * This check isn't done with atomic operations or under a lock because
	 * there's no need to. If the vcpuid bit is set, the vcpu is part of a
	 * rendezvous and the bit won't be cleared until the vcpu enters the
	 * rendezvous. On rendezvous exit, the cpuset is cleared and the vcpu
	 * will see an empty cpuset. So, the races are harmless.
	 */
	return (CPU_ISSET(vcpu_vcpuid(vcpu), info->rptr));
}

static __inline int
vcpu_suspended(struct vm_eventinfo *info)
{

	return (*info->sptr);
}

static __inline int
vcpu_reqidle(struct vm_eventinfo *info)
{

	return (*info->iptr);
}

int vcpu_debugged(struct vcpu *vcpu);

/*
 * Return true if device indicated by bus/slot/func is supposed to be a
 * pci passthrough device.
 *
 * Return false otherwise.
 */
bool vmm_is_pptdev(int bus, int slot, int func);

void *vm_iommu_domain(struct vm *vm);

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
void vcpu_notify_event(struct vcpu *vcpu, bool lapic_intr);
struct vmspace *vm_get_vmspace(struct vm *vm);
struct vatpic *vm_atpic(struct vm *vm);
struct vatpit *vm_atpit(struct vm *vm);
struct vpmtmr *vm_pmtmr(struct vm *vm);
struct vrtc *vm_rtc(struct vm *vm);

/*
 * Inject exception 'vector' into the guest vcpu. This function returns 0 on
 * success and non-zero on failure.
 *
 * Wrapper functions like 'vm_inject_gp()' should be preferred to calling
 * this function directly because they enforce the trap-like or fault-like
 * behavior of an exception.
 *
 * This function should only be called in the context of the thread that is
 * executing this vcpu.
 */
int vm_inject_exception(struct vcpu *vcpu, int vector, int err_valid,
    uint32_t errcode, int restart_instruction);

/*
 * This function is called after a VM-exit that occurred during exception or
 * interrupt delivery through the IDT. The format of 'intinfo' is described
 * in Figure 15-1, "EXITINTINFO for All Intercepts", APM, Vol 2.
 *
 * If a VM-exit handler completes the event delivery successfully then it
 * should call vm_exit_intinfo() to extinguish the pending event. For e.g.,
 * if the task switch emulation is triggered via a task gate then it should
 * call this function with 'intinfo=0' to indicate that the external event
 * is not pending anymore.
 *
 * Return value is 0 on success and non-zero on failure.
 */
int vm_exit_intinfo(struct vcpu *vcpu, uint64_t intinfo);

/*
 * This function is called before every VM-entry to retrieve a pending
 * event that should be injected into the guest. This function combines
 * nested events into a double or triple fault.
 *
 * Returns 0 if there are no events that need to be injected into the guest
 * and non-zero otherwise.
 */
int vm_entry_intinfo(struct vcpu *vcpu, uint64_t *info);

int vm_get_intinfo(struct vcpu *vcpu, uint64_t *info1, uint64_t *info2);

/*
 * Function used to keep track of the guest's TSC offset. The
 * offset is used by the virutalization extensions to provide a consistent
 * value for the Time Stamp Counter to the guest.
 */
void vm_set_tsc_offset(struct vcpu *vcpu, uint64_t offset);

enum vm_reg_name vm_segment_name(int seg_encoding);

struct vm_copyinfo {
	uint64_t	gpa;
	size_t		len;
	void		*hva;
	void		*cookie;
};

/*
 * Set up 'copyinfo[]' to copy to/from guest linear address space starting
 * at 'gla' and 'len' bytes long. The 'prot' should be set to PROT_READ for
 * a copyin or PROT_WRITE for a copyout. 
 *
 * retval	is_fault	Interpretation
 *   0		   0		Success
 *   0		   1		An exception was injected into the guest
 * EFAULT	  N/A		Unrecoverable error
 *
 * The 'copyinfo[]' can be passed to 'vm_copyin()' or 'vm_copyout()' only if
 * the return value is 0. The 'copyinfo[]' resources should be freed by calling
 * 'vm_copy_teardown()' after the copy is done.
 */
int vm_copy_setup(struct vcpu *vcpu, struct vm_guest_paging *paging,
    uint64_t gla, size_t len, int prot, struct vm_copyinfo *copyinfo,
    int num_copyinfo, int *is_fault);
void vm_copy_teardown(struct vm_copyinfo *copyinfo, int num_copyinfo);
void vm_copyin(struct vm_copyinfo *copyinfo, void *kaddr, size_t len);
void vm_copyout(const void *kaddr, struct vm_copyinfo *copyinfo, size_t len);

int vcpu_trace_exceptions(struct vcpu *vcpu);
int vcpu_trap_wbinvd(struct vcpu *vcpu);
#endif	/* KERNEL */

/*
 * Identifiers for optional vmm capabilities
 */
enum vm_cap_type {
	VM_CAP_HALT_EXIT,
	VM_CAP_MTRAP_EXIT,
	VM_CAP_PAUSE_EXIT,
	VM_CAP_UNRESTRICTED_GUEST,
	VM_CAP_ENABLE_INVPCID,
	VM_CAP_BPT_EXIT,
	VM_CAP_RDPID,
	VM_CAP_RDTSCP,
	VM_CAP_IPI_EXIT,
	VM_CAP_MASK_HWINTR,
	VM_CAP_RFLAGS_TF,
	VM_CAP_MAX
};

enum vm_intr_trigger {
	EDGE_TRIGGER,
	LEVEL_TRIGGER
};

/*
 * The 'access' field has the format specified in Table 21-2 of the Intel
 * Architecture Manual vol 3b.
 *
 * XXX The contents of the 'access' field are architecturally defined except
 * bit 16 - Segment Unusable.
 */
struct seg_desc {
	uint64_t	base;
	uint32_t	limit;
	uint32_t	access;
};
#define	SEG_DESC_TYPE(access)		((access) & 0x001f)
#define	SEG_DESC_DPL(access)		(((access) >> 5) & 0x3)
#define	SEG_DESC_PRESENT(access)	(((access) & 0x0080) ? 1 : 0)
#define	SEG_DESC_DEF32(access)		(((access) & 0x4000) ? 1 : 0)
#define	SEG_DESC_GRANULARITY(access)	(((access) & 0x8000) ? 1 : 0)
#define	SEG_DESC_UNUSABLE(access)	(((access) & 0x10000) ? 1 : 0)

enum vm_cpu_mode {
	CPU_MODE_REAL,
	CPU_MODE_PROTECTED,
	CPU_MODE_COMPATIBILITY,		/* IA-32E mode (CS.L = 0) */
	CPU_MODE_64BIT,			/* IA-32E mode (CS.L = 1) */
};

enum vm_paging_mode {
	PAGING_MODE_FLAT,
	PAGING_MODE_32,
	PAGING_MODE_PAE,
	PAGING_MODE_64,
	PAGING_MODE_64_LA57,
};

struct vm_guest_paging {
	uint64_t	cr3;
	int		cpl;
	enum vm_cpu_mode cpu_mode;
	enum vm_paging_mode paging_mode;
};

/*
 * The data structures 'vie' and 'vie_op' are meant to be opaque to the
 * consumers of instruction decoding. The only reason why their contents
 * need to be exposed is because they are part of the 'vm_exit' structure.
 */
struct vie_op {
	uint8_t		op_byte;	/* actual opcode byte */
	uint8_t		op_type;	/* type of operation (e.g. MOV) */
	uint16_t	op_flags;
};
_Static_assert(sizeof(struct vie_op) == 4, "ABI");
_Static_assert(_Alignof(struct vie_op) == 2, "ABI");

#define	VIE_INST_SIZE	15
struct vie {
	uint8_t		inst[VIE_INST_SIZE];	/* instruction bytes */
	uint8_t		num_valid;		/* size of the instruction */

/* The following fields are all zeroed upon restart. */
#define	vie_startzero	num_processed
	uint8_t		num_processed;

	uint8_t		addrsize:4, opsize:4;	/* address and operand sizes */
	uint8_t		rex_w:1,		/* REX prefix */
			rex_r:1,
			rex_x:1,
			rex_b:1,
			rex_present:1,
			repz_present:1,		/* REP/REPE/REPZ prefix */
			repnz_present:1,	/* REPNE/REPNZ prefix */
			opsize_override:1,	/* Operand size override */
			addrsize_override:1,	/* Address size override */
			segment_override:1;	/* Segment override */

	uint8_t		mod:2,			/* ModRM byte */
			reg:4,
			rm:4;

	uint8_t		ss:2,			/* SIB byte */
			vex_present:1,		/* VEX prefixed */
			vex_l:1,		/* L bit */
			index:4,		/* SIB byte */
			base:4;			/* SIB byte */

	uint8_t		disp_bytes;
	uint8_t		imm_bytes;

	uint8_t		scale;

	uint8_t		vex_reg:4,		/* vvvv: first source register specifier */
			vex_pp:2,		/* pp */
			_sparebits:2;

	uint8_t		_sparebytes[2];

	int		base_register;		/* VM_REG_GUEST_xyz */
	int		index_register;		/* VM_REG_GUEST_xyz */
	int		segment_register;	/* VM_REG_GUEST_xyz */

	int64_t		displacement;		/* optional addr displacement */
	int64_t		immediate;		/* optional immediate operand */

	uint8_t		decoded;	/* set to 1 if successfully decoded */

	uint8_t		_sparebyte;

	struct vie_op	op;			/* opcode description */
};
_Static_assert(sizeof(struct vie) == 64, "ABI");
_Static_assert(__offsetof(struct vie, disp_bytes) == 22, "ABI");
_Static_assert(__offsetof(struct vie, scale) == 24, "ABI");
_Static_assert(__offsetof(struct vie, base_register) == 28, "ABI");

enum vm_exitcode {
	VM_EXITCODE_INOUT,
	VM_EXITCODE_VMX,
	VM_EXITCODE_BOGUS,
	VM_EXITCODE_RDMSR,
	VM_EXITCODE_WRMSR,
	VM_EXITCODE_HLT,
	VM_EXITCODE_MTRAP,
	VM_EXITCODE_PAUSE,
	VM_EXITCODE_PAGING,
	VM_EXITCODE_INST_EMUL,
	VM_EXITCODE_SPINUP_AP,
	VM_EXITCODE_DEPRECATED1,	/* used to be SPINDOWN_CPU */
	VM_EXITCODE_RENDEZVOUS,
	VM_EXITCODE_IOAPIC_EOI,
	VM_EXITCODE_SUSPENDED,
	VM_EXITCODE_INOUT_STR,
	VM_EXITCODE_TASK_SWITCH,
	VM_EXITCODE_MONITOR,
	VM_EXITCODE_MWAIT,
	VM_EXITCODE_SVM,
	VM_EXITCODE_REQIDLE,
	VM_EXITCODE_DEBUG,
	VM_EXITCODE_VMINSN,
	VM_EXITCODE_BPT,
	VM_EXITCODE_IPI,
	VM_EXITCODE_DB,
	VM_EXITCODE_MAX
};

struct vm_inout {
	uint16_t	bytes:3;	/* 1 or 2 or 4 */
	uint16_t	in:1;
	uint16_t	string:1;
	uint16_t	rep:1;
	uint16_t	port;
	uint32_t	eax;		/* valid for out */
};

struct vm_inout_str {
	struct vm_inout	inout;		/* must be the first element */
	struct vm_guest_paging paging;
	uint64_t	rflags;
	uint64_t	cr0;
	uint64_t	index;
	uint64_t	count;		/* rep=1 (%rcx), rep=0 (1) */
	int		addrsize;
	enum vm_reg_name seg_name;
	struct seg_desc seg_desc;
};

enum task_switch_reason {
	TSR_CALL,
	TSR_IRET,
	TSR_JMP,
	TSR_IDT_GATE,	/* task gate in IDT */
};

struct vm_task_switch {
	uint16_t	tsssel;		/* new TSS selector */
	int		ext;		/* task switch due to external event */
	uint32_t	errcode;
	int		errcode_valid;	/* push 'errcode' on the new stack */
	enum task_switch_reason reason;
	struct vm_guest_paging paging;
};

struct vm_exit {
	enum vm_exitcode	exitcode;
	int			inst_length;	/* 0 means unknown */
	uint64_t		rip;
	union {
		struct vm_inout	inout;
		struct vm_inout_str inout_str;
		struct {
			uint64_t	gpa;
			int		fault_type;
		} paging;
		struct {
			uint64_t	gpa;
			uint64_t	gla;
			uint64_t	cs_base;
			int		cs_d;		/* CS.D */
			struct vm_guest_paging paging;
			struct vie	vie;
		} inst_emul;
		/*
		 * VMX specific payload. Used when there is no "better"
		 * exitcode to represent the VM-exit.
		 */
		struct {
			int		status;		/* vmx inst status */
			/*
			 * 'exit_reason' and 'exit_qualification' are valid
			 * only if 'status' is zero.
			 */
			uint32_t	exit_reason;
			uint64_t	exit_qualification;
			/*
			 * 'inst_error' and 'inst_type' are valid
			 * only if 'status' is non-zero.
			 */
			int		inst_type;
			int		inst_error;
		} vmx;
		/*
		 * SVM specific payload.
		 */
		struct {
			uint64_t	exitcode;
			uint64_t	exitinfo1;
			uint64_t	exitinfo2;
		} svm;
		struct {
			int		inst_length;
		} bpt;
		struct {
			int		trace_trap;
			int		pushf_intercept;
			int		tf_shadow_val;
			struct		vm_guest_paging paging;
		} dbg;
		struct {
			uint32_t	code;		/* ecx value */
			uint64_t	wval;
		} msr;
		struct {
			int		vcpu;
			uint64_t	rip;
		} spinup_ap;
		struct {
			uint64_t	rflags;
			uint64_t	intr_status;
		} hlt;
		struct {
			int		vector;
		} ioapic_eoi;
		struct {
			enum vm_suspend_how how;
		} suspended;
		struct {
			/*
			 * The destination vCPU mask is saved in vcpu->cpuset
			 * and is copied out to userspace separately to avoid
			 * ABI concerns.
			 */
			uint32_t mode;
			uint8_t vector;
		} ipi;
		struct vm_task_switch task_switch;
	} u;
};

/* APIs to inject faults into the guest */
void vm_inject_fault(struct vcpu *vcpu, int vector, int errcode_valid,
    int errcode);

static __inline void
vm_inject_ud(struct vcpu *vcpu)
{
	vm_inject_fault(vcpu, IDT_UD, 0, 0);
}

static __inline void
vm_inject_gp(struct vcpu *vcpu)
{
	vm_inject_fault(vcpu, IDT_GP, 1, 0);
}

static __inline void
vm_inject_ac(struct vcpu *vcpu, int errcode)
{
	vm_inject_fault(vcpu, IDT_AC, 1, errcode);
}

static __inline void
vm_inject_ss(struct vcpu *vcpu, int errcode)
{
	vm_inject_fault(vcpu, IDT_SS, 1, errcode);
}

void vm_inject_pf(struct vcpu *vcpu, int error_code, uint64_t cr2);

#endif	/* _VMM_H_ */