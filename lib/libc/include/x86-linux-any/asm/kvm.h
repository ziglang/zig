/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _ASM_X86_KVM_H
#define _ASM_X86_KVM_H

/*
 * KVM x86 specific structures and definitions
 *
 */

#include <linux/types.h>
#include <linux/ioctl.h>
#include <linux/stddef.h>

#define KVM_PIO_PAGE_OFFSET 1
#define KVM_COALESCED_MMIO_PAGE_OFFSET 2
#define KVM_DIRTY_LOG_PAGE_OFFSET 64

#define DE_VECTOR 0
#define DB_VECTOR 1
#define BP_VECTOR 3
#define OF_VECTOR 4
#define BR_VECTOR 5
#define UD_VECTOR 6
#define NM_VECTOR 7
#define DF_VECTOR 8
#define TS_VECTOR 10
#define NP_VECTOR 11
#define SS_VECTOR 12
#define GP_VECTOR 13
#define PF_VECTOR 14
#define MF_VECTOR 16
#define AC_VECTOR 17
#define MC_VECTOR 18
#define XM_VECTOR 19
#define VE_VECTOR 20

/* Select x86 specific features in <linux/kvm.h> */
#define __KVM_HAVE_PIT
#define __KVM_HAVE_IOAPIC
#define __KVM_HAVE_IRQ_LINE
#define __KVM_HAVE_MSI
#define __KVM_HAVE_USER_NMI
#define __KVM_HAVE_GUEST_DEBUG
#define __KVM_HAVE_MSIX
#define __KVM_HAVE_MCE
#define __KVM_HAVE_PIT_STATE2
#define __KVM_HAVE_XEN_HVM
#define __KVM_HAVE_VCPU_EVENTS
#define __KVM_HAVE_DEBUGREGS
#define __KVM_HAVE_XSAVE
#define __KVM_HAVE_XCRS
#define __KVM_HAVE_READONLY_MEM

/* Architectural interrupt line count. */
#define KVM_NR_INTERRUPTS 256

/* for KVM_GET_IRQCHIP and KVM_SET_IRQCHIP */
struct kvm_pic_state {
	__u8 last_irr;	/* edge detection */
	__u8 irr;		/* interrupt request register */
	__u8 imr;		/* interrupt mask register */
	__u8 isr;		/* interrupt service register */
	__u8 priority_add;	/* highest irq priority */
	__u8 irq_base;
	__u8 read_reg_select;
	__u8 poll;
	__u8 special_mask;
	__u8 init_state;
	__u8 auto_eoi;
	__u8 rotate_on_auto_eoi;
	__u8 special_fully_nested_mode;
	__u8 init4;		/* true if 4 byte init */
	__u8 elcr;		/* PIIX edge/trigger selection */
	__u8 elcr_mask;
};

#define KVM_IOAPIC_NUM_PINS  24
struct kvm_ioapic_state {
	__u64 base_address;
	__u32 ioregsel;
	__u32 id;
	__u32 irr;
	__u32 pad;
	union {
		__u64 bits;
		struct {
			__u8 vector;
			__u8 delivery_mode:3;
			__u8 dest_mode:1;
			__u8 delivery_status:1;
			__u8 polarity:1;
			__u8 remote_irr:1;
			__u8 trig_mode:1;
			__u8 mask:1;
			__u8 reserve:7;
			__u8 reserved[4];
			__u8 dest_id;
		} fields;
	} redirtbl[KVM_IOAPIC_NUM_PINS];
};

#define KVM_IRQCHIP_PIC_MASTER   0
#define KVM_IRQCHIP_PIC_SLAVE    1
#define KVM_IRQCHIP_IOAPIC       2
#define KVM_NR_IRQCHIPS          3

#define KVM_RUN_X86_SMM		 (1 << 0)
#define KVM_RUN_X86_BUS_LOCK     (1 << 1)

/* for KVM_GET_REGS and KVM_SET_REGS */
struct kvm_regs {
	/* out (KVM_GET_REGS) / in (KVM_SET_REGS) */
	__u64 rax, rbx, rcx, rdx;
	__u64 rsi, rdi, rsp, rbp;
	__u64 r8,  r9,  r10, r11;
	__u64 r12, r13, r14, r15;
	__u64 rip, rflags;
};

/* for KVM_GET_LAPIC and KVM_SET_LAPIC */
#define KVM_APIC_REG_SIZE 0x400
struct kvm_lapic_state {
	char regs[KVM_APIC_REG_SIZE];
};

struct kvm_segment {
	__u64 base;
	__u32 limit;
	__u16 selector;
	__u8  type;
	__u8  present, dpl, db, s, l, g, avl;
	__u8  unusable;
	__u8  padding;
};

struct kvm_dtable {
	__u64 base;
	__u16 limit;
	__u16 padding[3];
};


/* for KVM_GET_SREGS and KVM_SET_SREGS */
struct kvm_sregs {
	/* out (KVM_GET_SREGS) / in (KVM_SET_SREGS) */
	struct kvm_segment cs, ds, es, fs, gs, ss;
	struct kvm_segment tr, ldt;
	struct kvm_dtable gdt, idt;
	__u64 cr0, cr2, cr3, cr4, cr8;
	__u64 efer;
	__u64 apic_base;
	__u64 interrupt_bitmap[(KVM_NR_INTERRUPTS + 63) / 64];
};

struct kvm_sregs2 {
	/* out (KVM_GET_SREGS2) / in (KVM_SET_SREGS2) */
	struct kvm_segment cs, ds, es, fs, gs, ss;
	struct kvm_segment tr, ldt;
	struct kvm_dtable gdt, idt;
	__u64 cr0, cr2, cr3, cr4, cr8;
	__u64 efer;
	__u64 apic_base;
	__u64 flags;
	__u64 pdptrs[4];
};
#define KVM_SREGS2_FLAGS_PDPTRS_VALID 1

/* for KVM_GET_FPU and KVM_SET_FPU */
struct kvm_fpu {
	__u8  fpr[8][16];
	__u16 fcw;
	__u16 fsw;
	__u8  ftwx;  /* in fxsave format */
	__u8  pad1;
	__u16 last_opcode;
	__u64 last_ip;
	__u64 last_dp;
	__u8  xmm[16][16];
	__u32 mxcsr;
	__u32 pad2;
};

struct kvm_msr_entry {
	__u32 index;
	__u32 reserved;
	__u64 data;
};

/* for KVM_GET_MSRS and KVM_SET_MSRS */
struct kvm_msrs {
	__u32 nmsrs; /* number of msrs in entries */
	__u32 pad;

	struct kvm_msr_entry entries[];
};

/* for KVM_GET_MSR_INDEX_LIST */
struct kvm_msr_list {
	__u32 nmsrs; /* number of msrs in entries */
	__u32 indices[];
};

/* Maximum size of any access bitmap in bytes */
#define KVM_MSR_FILTER_MAX_BITMAP_SIZE 0x600

/* for KVM_X86_SET_MSR_FILTER */
struct kvm_msr_filter_range {
#define KVM_MSR_FILTER_READ  (1 << 0)
#define KVM_MSR_FILTER_WRITE (1 << 1)
#define KVM_MSR_FILTER_RANGE_VALID_MASK (KVM_MSR_FILTER_READ | \
					 KVM_MSR_FILTER_WRITE)
	__u32 flags;
	__u32 nmsrs; /* number of msrs in bitmap */
	__u32 base;  /* MSR index the bitmap starts at */
	__u8 *bitmap; /* a 1 bit allows the operations in flags, 0 denies */
};

#define KVM_MSR_FILTER_MAX_RANGES 16
struct kvm_msr_filter {
#define KVM_MSR_FILTER_DEFAULT_ALLOW (0 << 0)
#define KVM_MSR_FILTER_DEFAULT_DENY  (1 << 0)
#define KVM_MSR_FILTER_VALID_MASK (KVM_MSR_FILTER_DEFAULT_DENY)
	__u32 flags;
	struct kvm_msr_filter_range ranges[KVM_MSR_FILTER_MAX_RANGES];
};

struct kvm_cpuid_entry {
	__u32 function;
	__u32 eax;
	__u32 ebx;
	__u32 ecx;
	__u32 edx;
	__u32 padding;
};

/* for KVM_SET_CPUID */
struct kvm_cpuid {
	__u32 nent;
	__u32 padding;
	struct kvm_cpuid_entry entries[];
};

struct kvm_cpuid_entry2 {
	__u32 function;
	__u32 index;
	__u32 flags;
	__u32 eax;
	__u32 ebx;
	__u32 ecx;
	__u32 edx;
	__u32 padding[3];
};

#define KVM_CPUID_FLAG_SIGNIFCANT_INDEX		(1 << 0)
#define KVM_CPUID_FLAG_STATEFUL_FUNC		(1 << 1)
#define KVM_CPUID_FLAG_STATE_READ_NEXT		(1 << 2)

/* for KVM_SET_CPUID2 */
struct kvm_cpuid2 {
	__u32 nent;
	__u32 padding;
	struct kvm_cpuid_entry2 entries[];
};

/* for KVM_GET_PIT and KVM_SET_PIT */
struct kvm_pit_channel_state {
	__u32 count; /* can be 65536 */
	__u16 latched_count;
	__u8 count_latched;
	__u8 status_latched;
	__u8 status;
	__u8 read_state;
	__u8 write_state;
	__u8 write_latch;
	__u8 rw_mode;
	__u8 mode;
	__u8 bcd;
	__u8 gate;
	__s64 count_load_time;
};

struct kvm_debug_exit_arch {
	__u32 exception;
	__u32 pad;
	__u64 pc;
	__u64 dr6;
	__u64 dr7;
};

#define KVM_GUESTDBG_USE_SW_BP		0x00010000
#define KVM_GUESTDBG_USE_HW_BP		0x00020000
#define KVM_GUESTDBG_INJECT_DB		0x00040000
#define KVM_GUESTDBG_INJECT_BP		0x00080000
#define KVM_GUESTDBG_BLOCKIRQ		0x00100000

/* for KVM_SET_GUEST_DEBUG */
struct kvm_guest_debug_arch {
	__u64 debugreg[8];
};

struct kvm_pit_state {
	struct kvm_pit_channel_state channels[3];
};

#define KVM_PIT_FLAGS_HPET_LEGACY     0x00000001
#define KVM_PIT_FLAGS_SPEAKER_DATA_ON 0x00000002

struct kvm_pit_state2 {
	struct kvm_pit_channel_state channels[3];
	__u32 flags;
	__u32 reserved[9];
};

struct kvm_reinject_control {
	__u8 pit_reinject;
	__u8 reserved[31];
};

/* When set in flags, include corresponding fields on KVM_SET_VCPU_EVENTS */
#define KVM_VCPUEVENT_VALID_NMI_PENDING	0x00000001
#define KVM_VCPUEVENT_VALID_SIPI_VECTOR	0x00000002
#define KVM_VCPUEVENT_VALID_SHADOW	0x00000004
#define KVM_VCPUEVENT_VALID_SMM		0x00000008
#define KVM_VCPUEVENT_VALID_PAYLOAD	0x00000010
#define KVM_VCPUEVENT_VALID_TRIPLE_FAULT	0x00000020

/* Interrupt shadow states */
#define KVM_X86_SHADOW_INT_MOV_SS	0x01
#define KVM_X86_SHADOW_INT_STI		0x02

/* for KVM_GET/SET_VCPU_EVENTS */
struct kvm_vcpu_events {
	struct {
		__u8 injected;
		__u8 nr;
		__u8 has_error_code;
		__u8 pending;
		__u32 error_code;
	} exception;
	struct {
		__u8 injected;
		__u8 nr;
		__u8 soft;
		__u8 shadow;
	} interrupt;
	struct {
		__u8 injected;
		__u8 pending;
		__u8 masked;
		__u8 pad;
	} nmi;
	__u32 sipi_vector;
	__u32 flags;
	struct {
		__u8 smm;
		__u8 pending;
		__u8 smm_inside_nmi;
		__u8 latched_init;
	} smi;
	struct {
		__u8 pending;
	} triple_fault;
	__u8 reserved[26];
	__u8 exception_has_payload;
	__u64 exception_payload;
};

/* for KVM_GET/SET_DEBUGREGS */
struct kvm_debugregs {
	__u64 db[4];
	__u64 dr6;
	__u64 dr7;
	__u64 flags;
	__u64 reserved[9];
};

/* for KVM_CAP_XSAVE and KVM_CAP_XSAVE2 */
struct kvm_xsave {
	/*
	 * KVM_GET_XSAVE2 and KVM_SET_XSAVE write and read as many bytes
	 * as are returned by KVM_CHECK_EXTENSION(KVM_CAP_XSAVE2)
	 * respectively, when invoked on the vm file descriptor.
	 *
	 * The size value returned by KVM_CHECK_EXTENSION(KVM_CAP_XSAVE2)
	 * will always be at least 4096. Currently, it is only greater
	 * than 4096 if a dynamic feature has been enabled with
	 * ``arch_prctl()``, but this may change in the future.
	 *
	 * The offsets of the state save areas in struct kvm_xsave follow
	 * the contents of CPUID leaf 0xD on the host.
	 */
	__u32 region[1024];
	__u32 extra[];
};

#define KVM_MAX_XCRS	16

struct kvm_xcr {
	__u32 xcr;
	__u32 reserved;
	__u64 value;
};

struct kvm_xcrs {
	__u32 nr_xcrs;
	__u32 flags;
	struct kvm_xcr xcrs[KVM_MAX_XCRS];
	__u64 padding[16];
};

#define KVM_SYNC_X86_REGS      (1UL << 0)
#define KVM_SYNC_X86_SREGS     (1UL << 1)
#define KVM_SYNC_X86_EVENTS    (1UL << 2)

#define KVM_SYNC_X86_VALID_FIELDS \
	(KVM_SYNC_X86_REGS| \
	 KVM_SYNC_X86_SREGS| \
	 KVM_SYNC_X86_EVENTS)

/* kvm_sync_regs struct included by kvm_run struct */
struct kvm_sync_regs {
	/* Members of this structure are potentially malicious.
	 * Care must be taken by code reading, esp. interpreting,
	 * data fields from them inside KVM to prevent TOCTOU and
	 * double-fetch types of vulnerabilities.
	 */
	struct kvm_regs regs;
	struct kvm_sregs sregs;
	struct kvm_vcpu_events events;
};

#define KVM_X86_QUIRK_LINT0_REENABLED		(1 << 0)
#define KVM_X86_QUIRK_CD_NW_CLEARED		(1 << 1)
#define KVM_X86_QUIRK_LAPIC_MMIO_HOLE		(1 << 2)
#define KVM_X86_QUIRK_OUT_7E_INC_RIP		(1 << 3)
#define KVM_X86_QUIRK_MISC_ENABLE_NO_MWAIT	(1 << 4)
#define KVM_X86_QUIRK_FIX_HYPERCALL_INSN	(1 << 5)
#define KVM_X86_QUIRK_MWAIT_NEVER_UD_FAULTS	(1 << 6)

#define KVM_STATE_NESTED_FORMAT_VMX	0
#define KVM_STATE_NESTED_FORMAT_SVM	1

#define KVM_STATE_NESTED_GUEST_MODE	0x00000001
#define KVM_STATE_NESTED_RUN_PENDING	0x00000002
#define KVM_STATE_NESTED_EVMCS		0x00000004
#define KVM_STATE_NESTED_MTF_PENDING	0x00000008
#define KVM_STATE_NESTED_GIF_SET	0x00000100

#define KVM_STATE_NESTED_SMM_GUEST_MODE	0x00000001
#define KVM_STATE_NESTED_SMM_VMXON	0x00000002

#define KVM_STATE_NESTED_VMX_VMCS_SIZE	0x1000

#define KVM_STATE_NESTED_SVM_VMCB_SIZE	0x1000

#define KVM_STATE_VMX_PREEMPTION_TIMER_DEADLINE	0x00000001

/* attributes for system fd (group 0) */
#define KVM_X86_XCOMP_GUEST_SUPP	0

struct kvm_vmx_nested_state_data {
	__u8 vmcs12[KVM_STATE_NESTED_VMX_VMCS_SIZE];
	__u8 shadow_vmcs12[KVM_STATE_NESTED_VMX_VMCS_SIZE];
};

struct kvm_vmx_nested_state_hdr {
	__u64 vmxon_pa;
	__u64 vmcs12_pa;

	struct {
		__u16 flags;
	} smm;

	__u16 pad;

	__u32 flags;
	__u64 preemption_timer_deadline;
};

struct kvm_svm_nested_state_data {
	/* Save area only used if KVM_STATE_NESTED_RUN_PENDING.  */
	__u8 vmcb12[KVM_STATE_NESTED_SVM_VMCB_SIZE];
};

struct kvm_svm_nested_state_hdr {
	__u64 vmcb_pa;
};

/* for KVM_CAP_NESTED_STATE */
struct kvm_nested_state {
	__u16 flags;
	__u16 format;
	__u32 size;

	union {
		struct kvm_vmx_nested_state_hdr vmx;
		struct kvm_svm_nested_state_hdr svm;

		/* Pad the header to 128 bytes.  */
		__u8 pad[120];
	} hdr;

	/*
	 * Define data region as 0 bytes to preserve backwards-compatability
	 * to old definition of kvm_nested_state in order to avoid changing
	 * KVM_{GET,PUT}_NESTED_STATE ioctl values.
	 */
	union {
		__DECLARE_FLEX_ARRAY(struct kvm_vmx_nested_state_data, vmx);
		__DECLARE_FLEX_ARRAY(struct kvm_svm_nested_state_data, svm);
	} data;
};

/* for KVM_CAP_PMU_EVENT_FILTER */
struct kvm_pmu_event_filter {
	__u32 action;
	__u32 nevents;
	__u32 fixed_counter_bitmap;
	__u32 flags;
	__u32 pad[4];
	__u64 events[];
};

#define KVM_PMU_EVENT_ALLOW 0
#define KVM_PMU_EVENT_DENY 1

#define KVM_PMU_EVENT_FLAG_MASKED_EVENTS BIT(0)
#define KVM_PMU_EVENT_FLAGS_VALID_MASK (KVM_PMU_EVENT_FLAG_MASKED_EVENTS)

/*
 * Masked event layout.
 * Bits   Description
 * ----   -----------
 * 7:0    event select (low bits)
 * 15:8   umask match
 * 31:16  unused
 * 35:32  event select (high bits)
 * 36:54  unused
 * 55     exclude bit
 * 63:56  umask mask
 */

#define KVM_PMU_ENCODE_MASKED_ENTRY(event_select, mask, match, exclude) \
	(((event_select) & 0xFFULL) | (((event_select) & 0XF00ULL) << 24) | \
	(((mask) & 0xFFULL) << 56) | \
	(((match) & 0xFFULL) << 8) | \
	((__u64)(!!(exclude)) << 55))

#define KVM_PMU_MASKED_ENTRY_EVENT_SELECT \
	(GENMASK_ULL(7, 0) | GENMASK_ULL(35, 32))
#define KVM_PMU_MASKED_ENTRY_UMASK_MASK		(GENMASK_ULL(63, 56))
#define KVM_PMU_MASKED_ENTRY_UMASK_MATCH	(GENMASK_ULL(15, 8))
#define KVM_PMU_MASKED_ENTRY_EXCLUDE		(BIT_ULL(55))
#define KVM_PMU_MASKED_ENTRY_UMASK_MASK_SHIFT	(56)

/* for KVM_{GET,SET,HAS}_DEVICE_ATTR */
#define KVM_VCPU_TSC_CTRL 0 /* control group for the timestamp counter (TSC) */
#define   KVM_VCPU_TSC_OFFSET 0 /* attribute for the TSC offset */

#endif /* _ASM_X86_KVM_H */