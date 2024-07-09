/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _ASM_X86_KVM_H
#define _ASM_X86_KVM_H
#include <linux/types.h>
#include <linux/ioctl.h>
#define KVM_PIO_PAGE_OFFSET 1
#define KVM_COALESCED_MMIO_PAGE_OFFSET 2
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
#define KVM_NR_INTERRUPTS 256
struct kvm_memory_alias {
  __u32 slot;
  __u32 flags;
  __u64 guest_phys_addr;
  __u64 memory_size;
  __u64 target_phys_addr;
};
struct kvm_pic_state {
  __u8 last_irr;
  __u8 irr;
  __u8 imr;
  __u8 isr;
  __u8 priority_add;
  __u8 irq_base;
  __u8 read_reg_select;
  __u8 poll;
  __u8 special_mask;
  __u8 init_state;
  __u8 auto_eoi;
  __u8 rotate_on_auto_eoi;
  __u8 special_fully_nested_mode;
  __u8 init4;
  __u8 elcr;
  __u8 elcr_mask;
};
#define KVM_IOAPIC_NUM_PINS 24
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
      __u8 delivery_mode : 3;
      __u8 dest_mode : 1;
      __u8 delivery_status : 1;
      __u8 polarity : 1;
      __u8 remote_irr : 1;
      __u8 trig_mode : 1;
      __u8 mask : 1;
      __u8 reserve : 7;
      __u8 reserved[4];
      __u8 dest_id;
    } fields;
  } redirtbl[KVM_IOAPIC_NUM_PINS];
};
#define KVM_IRQCHIP_PIC_MASTER 0
#define KVM_IRQCHIP_PIC_SLAVE 1
#define KVM_IRQCHIP_IOAPIC 2
#define KVM_NR_IRQCHIPS 3
#define KVM_RUN_X86_SMM (1 << 0)
struct kvm_regs {
  __u64 rax, rbx, rcx, rdx;
  __u64 rsi, rdi, rsp, rbp;
  __u64 r8, r9, r10, r11;
  __u64 r12, r13, r14, r15;
  __u64 rip, rflags;
};
#define KVM_APIC_REG_SIZE 0x400
struct kvm_lapic_state {
  char regs[KVM_APIC_REG_SIZE];
};
struct kvm_segment {
  __u64 base;
  __u32 limit;
  __u16 selector;
  __u8 type;
  __u8 present, dpl, db, s, l, g, avl;
  __u8 unusable;
  __u8 padding;
};
struct kvm_dtable {
  __u64 base;
  __u16 limit;
  __u16 padding[3];
};
struct kvm_sregs {
  struct kvm_segment cs, ds, es, fs, gs, ss;
  struct kvm_segment tr, ldt;
  struct kvm_dtable gdt, idt;
  __u64 cr0, cr2, cr3, cr4, cr8;
  __u64 efer;
  __u64 apic_base;
  __u64 interrupt_bitmap[(KVM_NR_INTERRUPTS + 63) / 64];
};
struct kvm_fpu {
  __u8 fpr[8][16];
  __u16 fcw;
  __u16 fsw;
  __u8 ftwx;
  __u8 pad1;
  __u16 last_opcode;
  __u64 last_ip;
  __u64 last_dp;
  __u8 xmm[16][16];
  __u32 mxcsr;
  __u32 pad2;
};
struct kvm_msr_entry {
  __u32 index;
  __u32 reserved;
  __u64 data;
};
struct kvm_msrs {
  __u32 nmsrs;
  __u32 pad;
  struct kvm_msr_entry entries[0];
};
struct kvm_msr_list {
  __u32 nmsrs;
  __u32 indices[0];
};
#define KVM_MSR_FILTER_MAX_BITMAP_SIZE 0x600
struct kvm_msr_filter_range {
#define KVM_MSR_FILTER_READ (1 << 0)
#define KVM_MSR_FILTER_WRITE (1 << 1)
  __u32 flags;
  __u32 nmsrs;
  __u32 base;
  __u8 * bitmap;
};
#define KVM_MSR_FILTER_MAX_RANGES 16
struct kvm_msr_filter {
#define KVM_MSR_FILTER_DEFAULT_ALLOW (0 << 0)
#define KVM_MSR_FILTER_DEFAULT_DENY (1 << 0)
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
struct kvm_cpuid {
  __u32 nent;
  __u32 padding;
  struct kvm_cpuid_entry entries[0];
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
#define KVM_CPUID_FLAG_SIGNIFCANT_INDEX (1 << 0)
#define KVM_CPUID_FLAG_STATEFUL_FUNC (1 << 1)
#define KVM_CPUID_FLAG_STATE_READ_NEXT (1 << 2)
struct kvm_cpuid2 {
  __u32 nent;
  __u32 padding;
  struct kvm_cpuid_entry2 entries[0];
};
struct kvm_pit_channel_state {
  __u32 count;
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
#define KVM_GUESTDBG_USE_SW_BP 0x00010000
#define KVM_GUESTDBG_USE_HW_BP 0x00020000
#define KVM_GUESTDBG_INJECT_DB 0x00040000
#define KVM_GUESTDBG_INJECT_BP 0x00080000
struct kvm_guest_debug_arch {
  __u64 debugreg[8];
};
struct kvm_pit_state {
  struct kvm_pit_channel_state channels[3];
};
#define KVM_PIT_FLAGS_HPET_LEGACY 0x00000001
struct kvm_pit_state2 {
  struct kvm_pit_channel_state channels[3];
  __u32 flags;
  __u32 reserved[9];
};
struct kvm_reinject_control {
  __u8 pit_reinject;
  __u8 reserved[31];
};
#define KVM_VCPUEVENT_VALID_NMI_PENDING 0x00000001
#define KVM_VCPUEVENT_VALID_SIPI_VECTOR 0x00000002
#define KVM_VCPUEVENT_VALID_SHADOW 0x00000004
#define KVM_VCPUEVENT_VALID_SMM 0x00000008
#define KVM_VCPUEVENT_VALID_PAYLOAD 0x00000010
#define KVM_X86_SHADOW_INT_MOV_SS 0x01
#define KVM_X86_SHADOW_INT_STI 0x02
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
  __u8 reserved[27];
  __u8 exception_has_payload;
  __u64 exception_payload;
};
struct kvm_debugregs {
  __u64 db[4];
  __u64 dr6;
  __u64 dr7;
  __u64 flags;
  __u64 reserved[9];
};
struct kvm_xsave {
  __u32 region[1024];
};
#define KVM_MAX_XCRS 16
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
#define KVM_SYNC_X86_REGS (1UL << 0)
#define KVM_SYNC_X86_SREGS (1UL << 1)
#define KVM_SYNC_X86_EVENTS (1UL << 2)
#define KVM_SYNC_X86_VALID_FIELDS (KVM_SYNC_X86_REGS | KVM_SYNC_X86_SREGS | KVM_SYNC_X86_EVENTS)
struct kvm_sync_regs {
  struct kvm_regs regs;
  struct kvm_sregs sregs;
  struct kvm_vcpu_events events;
};
#define KVM_X86_QUIRK_LINT0_REENABLED (1 << 0)
#define KVM_X86_QUIRK_CD_NW_CLEARED (1 << 1)
#define KVM_X86_QUIRK_LAPIC_MMIO_HOLE (1 << 2)
#define KVM_X86_QUIRK_OUT_7E_INC_RIP (1 << 3)
#define KVM_X86_QUIRK_MISC_ENABLE_NO_MWAIT (1 << 4)
#define KVM_STATE_NESTED_FORMAT_VMX 0
#define KVM_STATE_NESTED_FORMAT_SVM 1
#define KVM_STATE_NESTED_GUEST_MODE 0x00000001
#define KVM_STATE_NESTED_RUN_PENDING 0x00000002
#define KVM_STATE_NESTED_EVMCS 0x00000004
#define KVM_STATE_NESTED_MTF_PENDING 0x00000008
#define KVM_STATE_NESTED_GIF_SET 0x00000100
#define KVM_STATE_NESTED_SMM_GUEST_MODE 0x00000001
#define KVM_STATE_NESTED_SMM_VMXON 0x00000002
#define KVM_STATE_NESTED_VMX_VMCS_SIZE 0x1000
#define KVM_STATE_NESTED_SVM_VMCB_SIZE 0x1000
#define KVM_STATE_VMX_PREEMPTION_TIMER_DEADLINE 0x00000001
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
  __u32 flags;
  __u64 preemption_timer_deadline;
};
struct kvm_svm_nested_state_data {
  __u8 vmcb12[KVM_STATE_NESTED_SVM_VMCB_SIZE];
};
struct kvm_svm_nested_state_hdr {
  __u64 vmcb_pa;
};
struct kvm_nested_state {
  __u16 flags;
  __u16 format;
  __u32 size;
  union {
    struct kvm_vmx_nested_state_hdr vmx;
    struct kvm_svm_nested_state_hdr svm;
    __u8 pad[120];
  } hdr;
  union {
    struct kvm_vmx_nested_state_data vmx[0];
    struct kvm_svm_nested_state_data svm[0];
  } data;
};
struct kvm_pmu_event_filter {
  __u32 action;
  __u32 nevents;
  __u32 fixed_counter_bitmap;
  __u32 flags;
  __u32 pad[4];
  __u64 events[0];
};
#define KVM_PMU_EVENT_ALLOW 0
#define KVM_PMU_EVENT_DENY 1
#endif
