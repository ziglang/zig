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
#ifndef __LINUX_KVM_H
#define __LINUX_KVM_H
#include <linux/types.h>
#include <linux/compiler.h>
#include <linux/ioctl.h>
#include <asm/kvm.h>
#define KVM_API_VERSION 12
#define KVM_TRC_SHIFT 16
#define KVM_TRC_ENTRYEXIT (1 << KVM_TRC_SHIFT)
#define KVM_TRC_HANDLER (1 << (KVM_TRC_SHIFT + 1))
#define KVM_TRC_VMENTRY (KVM_TRC_ENTRYEXIT + 0x01)
#define KVM_TRC_VMEXIT (KVM_TRC_ENTRYEXIT + 0x02)
#define KVM_TRC_PAGE_FAULT (KVM_TRC_HANDLER + 0x01)
#define KVM_TRC_HEAD_SIZE 12
#define KVM_TRC_CYCLE_SIZE 8
#define KVM_TRC_EXTRA_MAX 7
#define KVM_TRC_INJ_VIRQ (KVM_TRC_HANDLER + 0x02)
#define KVM_TRC_REDELIVER_EVT (KVM_TRC_HANDLER + 0x03)
#define KVM_TRC_PEND_INTR (KVM_TRC_HANDLER + 0x04)
#define KVM_TRC_IO_READ (KVM_TRC_HANDLER + 0x05)
#define KVM_TRC_IO_WRITE (KVM_TRC_HANDLER + 0x06)
#define KVM_TRC_CR_READ (KVM_TRC_HANDLER + 0x07)
#define KVM_TRC_CR_WRITE (KVM_TRC_HANDLER + 0x08)
#define KVM_TRC_DR_READ (KVM_TRC_HANDLER + 0x09)
#define KVM_TRC_DR_WRITE (KVM_TRC_HANDLER + 0x0A)
#define KVM_TRC_MSR_READ (KVM_TRC_HANDLER + 0x0B)
#define KVM_TRC_MSR_WRITE (KVM_TRC_HANDLER + 0x0C)
#define KVM_TRC_CPUID (KVM_TRC_HANDLER + 0x0D)
#define KVM_TRC_INTR (KVM_TRC_HANDLER + 0x0E)
#define KVM_TRC_NMI (KVM_TRC_HANDLER + 0x0F)
#define KVM_TRC_VMMCALL (KVM_TRC_HANDLER + 0x10)
#define KVM_TRC_HLT (KVM_TRC_HANDLER + 0x11)
#define KVM_TRC_CLTS (KVM_TRC_HANDLER + 0x12)
#define KVM_TRC_LMSW (KVM_TRC_HANDLER + 0x13)
#define KVM_TRC_APIC_ACCESS (KVM_TRC_HANDLER + 0x14)
#define KVM_TRC_TDP_FAULT (KVM_TRC_HANDLER + 0x15)
#define KVM_TRC_GTLB_WRITE (KVM_TRC_HANDLER + 0x16)
#define KVM_TRC_STLB_WRITE (KVM_TRC_HANDLER + 0x17)
#define KVM_TRC_STLB_INVAL (KVM_TRC_HANDLER + 0x18)
#define KVM_TRC_PPC_INSTR (KVM_TRC_HANDLER + 0x19)
struct kvm_user_trace_setup {
  __u32 buf_size;
  __u32 buf_nr;
};
#define __KVM_DEPRECATED_MAIN_W_0x06 _IOW(KVMIO, 0x06, struct kvm_user_trace_setup)
#define __KVM_DEPRECATED_MAIN_0x07 _IO(KVMIO, 0x07)
#define __KVM_DEPRECATED_MAIN_0x08 _IO(KVMIO, 0x08)
#define __KVM_DEPRECATED_VM_R_0x70 _IOR(KVMIO, 0x70, struct kvm_assigned_irq)
struct kvm_breakpoint {
  __u32 enabled;
  __u32 padding;
  __u64 address;
};
struct kvm_debug_guest {
  __u32 enabled;
  __u32 pad;
  struct kvm_breakpoint breakpoints[4];
  __u32 singlestep;
};
#define __KVM_DEPRECATED_VCPU_W_0x87 _IOW(KVMIO, 0x87, struct kvm_debug_guest)
struct kvm_memory_region {
  __u32 slot;
  __u32 flags;
  __u64 guest_phys_addr;
  __u64 memory_size;
};
struct kvm_userspace_memory_region {
  __u32 slot;
  __u32 flags;
  __u64 guest_phys_addr;
  __u64 memory_size;
  __u64 userspace_addr;
};
#define KVM_MEM_LOG_DIRTY_PAGES (1UL << 0)
#define KVM_MEM_READONLY (1UL << 1)
struct kvm_irq_level {
  union {
    __u32 irq;
    __s32 status;
  };
  __u32 level;
};
struct kvm_irqchip {
  __u32 chip_id;
  __u32 pad;
  union {
    char dummy[512];
#ifdef __KVM_HAVE_PIT
    struct kvm_pic_state pic;
#endif
#ifdef __KVM_HAVE_IOAPIC
    struct kvm_ioapic_state ioapic;
#endif
  } chip;
};
struct kvm_pit_config {
  __u32 flags;
  __u32 pad[15];
};
#define KVM_PIT_SPEAKER_DUMMY 1
struct kvm_s390_skeys {
  __u64 start_gfn;
  __u64 count;
  __u64 skeydata_addr;
  __u32 flags;
  __u32 reserved[9];
};
#define KVM_S390_CMMA_PEEK (1 << 0)
struct kvm_s390_cmma_log {
  __u64 start_gfn;
  __u32 count;
  __u32 flags;
  union {
    __u64 remaining;
    __u64 mask;
  };
  __u64 values;
};
struct kvm_hyperv_exit {
#define KVM_EXIT_HYPERV_SYNIC 1
#define KVM_EXIT_HYPERV_HCALL 2
#define KVM_EXIT_HYPERV_SYNDBG 3
  __u32 type;
  __u32 pad1;
  union {
    struct {
      __u32 msr;
      __u32 pad2;
      __u64 control;
      __u64 evt_page;
      __u64 msg_page;
    } synic;
    struct {
      __u64 input;
      __u64 result;
      __u64 params[2];
    } hcall;
    struct {
      __u32 msr;
      __u32 pad2;
      __u64 control;
      __u64 status;
      __u64 send_page;
      __u64 recv_page;
      __u64 pending_page;
    } syndbg;
  } u;
};
#define KVM_S390_GET_SKEYS_NONE 1
#define KVM_S390_SKEYS_MAX 1048576
#define KVM_EXIT_UNKNOWN 0
#define KVM_EXIT_EXCEPTION 1
#define KVM_EXIT_IO 2
#define KVM_EXIT_HYPERCALL 3
#define KVM_EXIT_DEBUG 4
#define KVM_EXIT_HLT 5
#define KVM_EXIT_MMIO 6
#define KVM_EXIT_IRQ_WINDOW_OPEN 7
#define KVM_EXIT_SHUTDOWN 8
#define KVM_EXIT_FAIL_ENTRY 9
#define KVM_EXIT_INTR 10
#define KVM_EXIT_SET_TPR 11
#define KVM_EXIT_TPR_ACCESS 12
#define KVM_EXIT_S390_SIEIC 13
#define KVM_EXIT_S390_RESET 14
#define KVM_EXIT_DCR 15
#define KVM_EXIT_NMI 16
#define KVM_EXIT_INTERNAL_ERROR 17
#define KVM_EXIT_OSI 18
#define KVM_EXIT_PAPR_HCALL 19
#define KVM_EXIT_S390_UCONTROL 20
#define KVM_EXIT_WATCHDOG 21
#define KVM_EXIT_S390_TSCH 22
#define KVM_EXIT_EPR 23
#define KVM_EXIT_SYSTEM_EVENT 24
#define KVM_EXIT_S390_STSI 25
#define KVM_EXIT_IOAPIC_EOI 26
#define KVM_EXIT_HYPERV 27
#define KVM_EXIT_ARM_NISV 28
#define KVM_EXIT_X86_RDMSR 29
#define KVM_EXIT_X86_WRMSR 30
#define KVM_INTERNAL_ERROR_EMULATION 1
#define KVM_INTERNAL_ERROR_SIMUL_EX 2
#define KVM_INTERNAL_ERROR_DELIVERY_EV 3
#define KVM_INTERNAL_ERROR_UNEXPECTED_EXIT_REASON 4
struct kvm_run {
  __u8 request_interrupt_window;
  __u8 immediate_exit;
  __u8 padding1[6];
  __u32 exit_reason;
  __u8 ready_for_interrupt_injection;
  __u8 if_flag;
  __u16 flags;
  __u64 cr8;
  __u64 apic_base;
#ifdef __KVM_S390
  __u64 psw_mask;
  __u64 psw_addr;
#endif
  union {
    struct {
      __u64 hardware_exit_reason;
    } hw;
    struct {
      __u64 hardware_entry_failure_reason;
      __u32 cpu;
    } fail_entry;
    struct {
      __u32 exception;
      __u32 error_code;
    } ex;
    struct {
#define KVM_EXIT_IO_IN 0
#define KVM_EXIT_IO_OUT 1
      __u8 direction;
      __u8 size;
      __u16 port;
      __u32 count;
      __u64 data_offset;
    } io;
    struct {
      struct kvm_debug_exit_arch arch;
    } debug;
    struct {
      __u64 phys_addr;
      __u8 data[8];
      __u32 len;
      __u8 is_write;
    } mmio;
    struct {
      __u64 nr;
      __u64 args[6];
      __u64 ret;
      __u32 longmode;
      __u32 pad;
    } hypercall;
    struct {
      __u64 rip;
      __u32 is_write;
      __u32 pad;
    } tpr_access;
    struct {
      __u8 icptcode;
      __u16 ipa;
      __u32 ipb;
    } s390_sieic;
#define KVM_S390_RESET_POR 1
#define KVM_S390_RESET_CLEAR 2
#define KVM_S390_RESET_SUBSYSTEM 4
#define KVM_S390_RESET_CPU_INIT 8
#define KVM_S390_RESET_IPL 16
    __u64 s390_reset_flags;
    struct {
      __u64 trans_exc_code;
      __u32 pgm_code;
    } s390_ucontrol;
    struct {
      __u32 dcrn;
      __u32 data;
      __u8 is_write;
    } dcr;
    struct {
      __u32 suberror;
      __u32 ndata;
      __u64 data[16];
    } internal;
    struct {
      __u64 gprs[32];
    } osi;
    struct {
      __u64 nr;
      __u64 ret;
      __u64 args[9];
    } papr_hcall;
    struct {
      __u16 subchannel_id;
      __u16 subchannel_nr;
      __u32 io_int_parm;
      __u32 io_int_word;
      __u32 ipb;
      __u8 dequeued;
    } s390_tsch;
    struct {
      __u32 epr;
    } epr;
    struct {
#define KVM_SYSTEM_EVENT_SHUTDOWN 1
#define KVM_SYSTEM_EVENT_RESET 2
#define KVM_SYSTEM_EVENT_CRASH 3
      __u32 type;
      __u64 flags;
    } system_event;
    struct {
      __u64 addr;
      __u8 ar;
      __u8 reserved;
      __u8 fc;
      __u8 sel1;
      __u16 sel2;
    } s390_stsi;
    struct {
      __u8 vector;
    } eoi;
    struct kvm_hyperv_exit hyperv;
    struct {
      __u64 esr_iss;
      __u64 fault_ipa;
    } arm_nisv;
    struct {
      __u8 error;
      __u8 pad[7];
#define KVM_MSR_EXIT_REASON_INVAL (1 << 0)
#define KVM_MSR_EXIT_REASON_UNKNOWN (1 << 1)
#define KVM_MSR_EXIT_REASON_FILTER (1 << 2)
      __u32 reason;
      __u32 index;
      __u64 data;
    } msr;
    char padding[256];
  };
#define SYNC_REGS_SIZE_BYTES 2048
  __u64 kvm_valid_regs;
  __u64 kvm_dirty_regs;
  union {
    struct kvm_sync_regs regs;
    char padding[SYNC_REGS_SIZE_BYTES];
  } s;
};
struct kvm_coalesced_mmio_zone {
  __u64 addr;
  __u32 size;
  union {
    __u32 pad;
    __u32 pio;
  };
};
struct kvm_coalesced_mmio {
  __u64 phys_addr;
  __u32 len;
  union {
    __u32 pad;
    __u32 pio;
  };
  __u8 data[8];
};
struct kvm_coalesced_mmio_ring {
  __u32 first, last;
  struct kvm_coalesced_mmio coalesced_mmio[0];
};
#define KVM_COALESCED_MMIO_MAX ((PAGE_SIZE - sizeof(struct kvm_coalesced_mmio_ring)) / sizeof(struct kvm_coalesced_mmio))
struct kvm_translation {
  __u64 linear_address;
  __u64 physical_address;
  __u8 valid;
  __u8 writeable;
  __u8 usermode;
  __u8 pad[5];
};
struct kvm_s390_mem_op {
  __u64 gaddr;
  __u64 flags;
  __u32 size;
  __u32 op;
  __u64 buf;
  union {
    __u8 ar;
    __u32 sida_offset;
    __u8 reserved[32];
  };
};
#define KVM_S390_MEMOP_LOGICAL_READ 0
#define KVM_S390_MEMOP_LOGICAL_WRITE 1
#define KVM_S390_MEMOP_SIDA_READ 2
#define KVM_S390_MEMOP_SIDA_WRITE 3
#define KVM_S390_MEMOP_F_CHECK_ONLY (1ULL << 0)
#define KVM_S390_MEMOP_F_INJECT_EXCEPTION (1ULL << 1)
struct kvm_interrupt {
  __u32 irq;
};
struct kvm_dirty_log {
  __u32 slot;
  __u32 padding1;
  union {
    void __user * dirty_bitmap;
    __u64 padding2;
  };
};
struct kvm_clear_dirty_log {
  __u32 slot;
  __u32 num_pages;
  __u64 first_page;
  union {
    void __user * dirty_bitmap;
    __u64 padding2;
  };
};
struct kvm_signal_mask {
  __u32 len;
  __u8 sigset[0];
};
struct kvm_tpr_access_ctl {
  __u32 enabled;
  __u32 flags;
  __u32 reserved[8];
};
struct kvm_vapic_addr {
  __u64 vapic_addr;
};
#define KVM_MP_STATE_RUNNABLE 0
#define KVM_MP_STATE_UNINITIALIZED 1
#define KVM_MP_STATE_INIT_RECEIVED 2
#define KVM_MP_STATE_HALTED 3
#define KVM_MP_STATE_SIPI_RECEIVED 4
#define KVM_MP_STATE_STOPPED 5
#define KVM_MP_STATE_CHECK_STOP 6
#define KVM_MP_STATE_OPERATING 7
#define KVM_MP_STATE_LOAD 8
struct kvm_mp_state {
  __u32 mp_state;
};
struct kvm_s390_psw {
  __u64 mask;
  __u64 addr;
};
#define KVM_S390_SIGP_STOP 0xfffe0000u
#define KVM_S390_PROGRAM_INT 0xfffe0001u
#define KVM_S390_SIGP_SET_PREFIX 0xfffe0002u
#define KVM_S390_RESTART 0xfffe0003u
#define KVM_S390_INT_PFAULT_INIT 0xfffe0004u
#define KVM_S390_INT_PFAULT_DONE 0xfffe0005u
#define KVM_S390_MCHK 0xfffe1000u
#define KVM_S390_INT_CLOCK_COMP 0xffff1004u
#define KVM_S390_INT_CPU_TIMER 0xffff1005u
#define KVM_S390_INT_VIRTIO 0xffff2603u
#define KVM_S390_INT_SERVICE 0xffff2401u
#define KVM_S390_INT_EMERGENCY 0xffff1201u
#define KVM_S390_INT_EXTERNAL_CALL 0xffff1202u
#define KVM_S390_INT_IO(ai,cssid,ssid,schid) (((schid)) | ((ssid) << 16) | ((cssid) << 18) | ((ai) << 26))
#define KVM_S390_INT_IO_MIN 0x00000000u
#define KVM_S390_INT_IO_MAX 0xfffdffffu
#define KVM_S390_INT_IO_AI_MASK 0x04000000u
struct kvm_s390_interrupt {
  __u32 type;
  __u32 parm;
  __u64 parm64;
};
struct kvm_s390_io_info {
  __u16 subchannel_id;
  __u16 subchannel_nr;
  __u32 io_int_parm;
  __u32 io_int_word;
};
struct kvm_s390_ext_info {
  __u32 ext_params;
  __u32 pad;
  __u64 ext_params2;
};
struct kvm_s390_pgm_info {
  __u64 trans_exc_code;
  __u64 mon_code;
  __u64 per_address;
  __u32 data_exc_code;
  __u16 code;
  __u16 mon_class_nr;
  __u8 per_code;
  __u8 per_atmid;
  __u8 exc_access_id;
  __u8 per_access_id;
  __u8 op_access_id;
#define KVM_S390_PGM_FLAGS_ILC_VALID 0x01
#define KVM_S390_PGM_FLAGS_ILC_0 0x02
#define KVM_S390_PGM_FLAGS_ILC_1 0x04
#define KVM_S390_PGM_FLAGS_ILC_MASK 0x06
#define KVM_S390_PGM_FLAGS_NO_REWIND 0x08
  __u8 flags;
  __u8 pad[2];
};
struct kvm_s390_prefix_info {
  __u32 address;
};
struct kvm_s390_extcall_info {
  __u16 code;
};
struct kvm_s390_emerg_info {
  __u16 code;
};
#define KVM_S390_STOP_FLAG_STORE_STATUS 0x01
struct kvm_s390_stop_info {
  __u32 flags;
};
struct kvm_s390_mchk_info {
  __u64 cr14;
  __u64 mcic;
  __u64 failing_storage_address;
  __u32 ext_damage_code;
  __u32 pad;
  __u8 fixed_logout[16];
};
struct kvm_s390_irq {
  __u64 type;
  union {
    struct kvm_s390_io_info io;
    struct kvm_s390_ext_info ext;
    struct kvm_s390_pgm_info pgm;
    struct kvm_s390_emerg_info emerg;
    struct kvm_s390_extcall_info extcall;
    struct kvm_s390_prefix_info prefix;
    struct kvm_s390_stop_info stop;
    struct kvm_s390_mchk_info mchk;
    char reserved[64];
  } u;
};
struct kvm_s390_irq_state {
  __u64 buf;
  __u32 flags;
  __u32 len;
  __u32 reserved[4];
};
#define KVM_GUESTDBG_ENABLE 0x00000001
#define KVM_GUESTDBG_SINGLESTEP 0x00000002
struct kvm_guest_debug {
  __u32 control;
  __u32 pad;
  struct kvm_guest_debug_arch arch;
};
enum {
  kvm_ioeventfd_flag_nr_datamatch,
  kvm_ioeventfd_flag_nr_pio,
  kvm_ioeventfd_flag_nr_deassign,
  kvm_ioeventfd_flag_nr_virtio_ccw_notify,
  kvm_ioeventfd_flag_nr_fast_mmio,
  kvm_ioeventfd_flag_nr_max,
};
#define KVM_IOEVENTFD_FLAG_DATAMATCH (1 << kvm_ioeventfd_flag_nr_datamatch)
#define KVM_IOEVENTFD_FLAG_PIO (1 << kvm_ioeventfd_flag_nr_pio)
#define KVM_IOEVENTFD_FLAG_DEASSIGN (1 << kvm_ioeventfd_flag_nr_deassign)
#define KVM_IOEVENTFD_FLAG_VIRTIO_CCW_NOTIFY (1 << kvm_ioeventfd_flag_nr_virtio_ccw_notify)
#define KVM_IOEVENTFD_VALID_FLAG_MASK ((1 << kvm_ioeventfd_flag_nr_max) - 1)
struct kvm_ioeventfd {
  __u64 datamatch;
  __u64 addr;
  __u32 len;
  __s32 fd;
  __u32 flags;
  __u8 pad[36];
};
#define KVM_X86_DISABLE_EXITS_MWAIT (1 << 0)
#define KVM_X86_DISABLE_EXITS_HLT (1 << 1)
#define KVM_X86_DISABLE_EXITS_PAUSE (1 << 2)
#define KVM_X86_DISABLE_EXITS_CSTATE (1 << 3)
#define KVM_X86_DISABLE_VALID_EXITS (KVM_X86_DISABLE_EXITS_MWAIT | KVM_X86_DISABLE_EXITS_HLT | KVM_X86_DISABLE_EXITS_PAUSE | KVM_X86_DISABLE_EXITS_CSTATE)
struct kvm_enable_cap {
  __u32 cap;
  __u32 flags;
  __u64 args[4];
  __u8 pad[64];
};
#define KVM_PPC_PVINFO_FLAGS_EV_IDLE (1 << 0)
struct kvm_ppc_pvinfo {
  __u32 flags;
  __u32 hcall[4];
  __u8 pad[108];
};
#define KVM_PPC_PAGE_SIZES_MAX_SZ 8
struct kvm_ppc_one_page_size {
  __u32 page_shift;
  __u32 pte_enc;
};
struct kvm_ppc_one_seg_page_size {
  __u32 page_shift;
  __u32 slb_enc;
  struct kvm_ppc_one_page_size enc[KVM_PPC_PAGE_SIZES_MAX_SZ];
};
#define KVM_PPC_PAGE_SIZES_REAL 0x00000001
#define KVM_PPC_1T_SEGMENTS 0x00000002
#define KVM_PPC_NO_HASH 0x00000004
struct kvm_ppc_smmu_info {
  __u64 flags;
  __u32 slb_size;
  __u16 data_keys;
  __u16 instr_keys;
  struct kvm_ppc_one_seg_page_size sps[KVM_PPC_PAGE_SIZES_MAX_SZ];
};
struct kvm_ppc_resize_hpt {
  __u64 flags;
  __u32 shift;
  __u32 pad;
};
#define KVMIO 0xAE
#define KVM_VM_S390_UCONTROL 1
#define KVM_VM_PPC_HV 1
#define KVM_VM_PPC_PR 2
#define KVM_VM_MIPS_AUTO 0
#define KVM_VM_MIPS_VZ 1
#define KVM_VM_MIPS_TE 2
#define KVM_S390_SIE_PAGE_OFFSET 1
#define KVM_VM_TYPE_ARM_IPA_SIZE_MASK 0xffULL
#define KVM_VM_TYPE_ARM_IPA_SIZE(x) ((x) & KVM_VM_TYPE_ARM_IPA_SIZE_MASK)
#define KVM_GET_API_VERSION _IO(KVMIO, 0x00)
#define KVM_CREATE_VM _IO(KVMIO, 0x01)
#define KVM_GET_MSR_INDEX_LIST _IOWR(KVMIO, 0x02, struct kvm_msr_list)
#define KVM_S390_ENABLE_SIE _IO(KVMIO, 0x06)
#define KVM_CHECK_EXTENSION _IO(KVMIO, 0x03)
#define KVM_GET_VCPU_MMAP_SIZE _IO(KVMIO, 0x04)
#define KVM_GET_SUPPORTED_CPUID _IOWR(KVMIO, 0x05, struct kvm_cpuid2)
#define KVM_TRACE_ENABLE __KVM_DEPRECATED_MAIN_W_0x06
#define KVM_TRACE_PAUSE __KVM_DEPRECATED_MAIN_0x07
#define KVM_TRACE_DISABLE __KVM_DEPRECATED_MAIN_0x08
#define KVM_GET_EMULATED_CPUID _IOWR(KVMIO, 0x09, struct kvm_cpuid2)
#define KVM_GET_MSR_FEATURE_INDEX_LIST _IOWR(KVMIO, 0x0a, struct kvm_msr_list)
#define KVM_CAP_IRQCHIP 0
#define KVM_CAP_HLT 1
#define KVM_CAP_MMU_SHADOW_CACHE_CONTROL 2
#define KVM_CAP_USER_MEMORY 3
#define KVM_CAP_SET_TSS_ADDR 4
#define KVM_CAP_VAPIC 6
#define KVM_CAP_EXT_CPUID 7
#define KVM_CAP_CLOCKSOURCE 8
#define KVM_CAP_NR_VCPUS 9
#define KVM_CAP_NR_MEMSLOTS 10
#define KVM_CAP_PIT 11
#define KVM_CAP_NOP_IO_DELAY 12
#define KVM_CAP_PV_MMU 13
#define KVM_CAP_MP_STATE 14
#define KVM_CAP_COALESCED_MMIO 15
#define KVM_CAP_SYNC_MMU 16
#define KVM_CAP_IOMMU 18
#define KVM_CAP_DESTROY_MEMORY_REGION_WORKS 21
#define KVM_CAP_USER_NMI 22
#ifdef __KVM_HAVE_GUEST_DEBUG
#define KVM_CAP_SET_GUEST_DEBUG 23
#endif
#ifdef __KVM_HAVE_PIT
#define KVM_CAP_REINJECT_CONTROL 24
#endif
#define KVM_CAP_IRQ_ROUTING 25
#define KVM_CAP_IRQ_INJECT_STATUS 26
#define KVM_CAP_ASSIGN_DEV_IRQ 29
#define KVM_CAP_JOIN_MEMORY_REGIONS_WORKS 30
#ifdef __KVM_HAVE_MCE
#define KVM_CAP_MCE 31
#endif
#define KVM_CAP_IRQFD 32
#ifdef __KVM_HAVE_PIT
#define KVM_CAP_PIT2 33
#endif
#define KVM_CAP_SET_BOOT_CPU_ID 34
#ifdef __KVM_HAVE_PIT_STATE2
#define KVM_CAP_PIT_STATE2 35
#endif
#define KVM_CAP_IOEVENTFD 36
#define KVM_CAP_SET_IDENTITY_MAP_ADDR 37
#ifdef __KVM_HAVE_XEN_HVM
#define KVM_CAP_XEN_HVM 38
#endif
#define KVM_CAP_ADJUST_CLOCK 39
#define KVM_CAP_INTERNAL_ERROR_DATA 40
#ifdef __KVM_HAVE_VCPU_EVENTS
#define KVM_CAP_VCPU_EVENTS 41
#endif
#define KVM_CAP_S390_PSW 42
#define KVM_CAP_PPC_SEGSTATE 43
#define KVM_CAP_HYPERV 44
#define KVM_CAP_HYPERV_VAPIC 45
#define KVM_CAP_HYPERV_SPIN 46
#define KVM_CAP_PCI_SEGMENT 47
#define KVM_CAP_PPC_PAIRED_SINGLES 48
#define KVM_CAP_INTR_SHADOW 49
#ifdef __KVM_HAVE_DEBUGREGS
#define KVM_CAP_DEBUGREGS 50
#endif
#define KVM_CAP_X86_ROBUST_SINGLESTEP 51
#define KVM_CAP_PPC_OSI 52
#define KVM_CAP_PPC_UNSET_IRQ 53
#define KVM_CAP_ENABLE_CAP 54
#ifdef __KVM_HAVE_XSAVE
#define KVM_CAP_XSAVE 55
#endif
#ifdef __KVM_HAVE_XCRS
#define KVM_CAP_XCRS 56
#endif
#define KVM_CAP_PPC_GET_PVINFO 57
#define KVM_CAP_PPC_IRQ_LEVEL 58
#define KVM_CAP_ASYNC_PF 59
#define KVM_CAP_TSC_CONTROL 60
#define KVM_CAP_GET_TSC_KHZ 61
#define KVM_CAP_PPC_BOOKE_SREGS 62
#define KVM_CAP_SPAPR_TCE 63
#define KVM_CAP_PPC_SMT 64
#define KVM_CAP_PPC_RMA 65
#define KVM_CAP_MAX_VCPUS 66
#define KVM_CAP_PPC_HIOR 67
#define KVM_CAP_PPC_PAPR 68
#define KVM_CAP_SW_TLB 69
#define KVM_CAP_ONE_REG 70
#define KVM_CAP_S390_GMAP 71
#define KVM_CAP_TSC_DEADLINE_TIMER 72
#define KVM_CAP_S390_UCONTROL 73
#define KVM_CAP_SYNC_REGS 74
#define KVM_CAP_PCI_2_3 75
#define KVM_CAP_KVMCLOCK_CTRL 76
#define KVM_CAP_SIGNAL_MSI 77
#define KVM_CAP_PPC_GET_SMMU_INFO 78
#define KVM_CAP_S390_COW 79
#define KVM_CAP_PPC_ALLOC_HTAB 80
#define KVM_CAP_READONLY_MEM 81
#define KVM_CAP_IRQFD_RESAMPLE 82
#define KVM_CAP_PPC_BOOKE_WATCHDOG 83
#define KVM_CAP_PPC_HTAB_FD 84
#define KVM_CAP_S390_CSS_SUPPORT 85
#define KVM_CAP_PPC_EPR 86
#define KVM_CAP_ARM_PSCI 87
#define KVM_CAP_ARM_SET_DEVICE_ADDR 88
#define KVM_CAP_DEVICE_CTRL 89
#define KVM_CAP_IRQ_MPIC 90
#define KVM_CAP_PPC_RTAS 91
#define KVM_CAP_IRQ_XICS 92
#define KVM_CAP_ARM_EL1_32BIT 93
#define KVM_CAP_SPAPR_MULTITCE 94
#define KVM_CAP_EXT_EMUL_CPUID 95
#define KVM_CAP_HYPERV_TIME 96
#define KVM_CAP_IOAPIC_POLARITY_IGNORED 97
#define KVM_CAP_ENABLE_CAP_VM 98
#define KVM_CAP_S390_IRQCHIP 99
#define KVM_CAP_IOEVENTFD_NO_LENGTH 100
#define KVM_CAP_VM_ATTRIBUTES 101
#define KVM_CAP_ARM_PSCI_0_2 102
#define KVM_CAP_PPC_FIXUP_HCALL 103
#define KVM_CAP_PPC_ENABLE_HCALL 104
#define KVM_CAP_CHECK_EXTENSION_VM 105
#define KVM_CAP_S390_USER_SIGP 106
#define KVM_CAP_S390_VECTOR_REGISTERS 107
#define KVM_CAP_S390_MEM_OP 108
#define KVM_CAP_S390_USER_STSI 109
#define KVM_CAP_S390_SKEYS 110
#define KVM_CAP_MIPS_FPU 111
#define KVM_CAP_MIPS_MSA 112
#define KVM_CAP_S390_INJECT_IRQ 113
#define KVM_CAP_S390_IRQ_STATE 114
#define KVM_CAP_PPC_HWRNG 115
#define KVM_CAP_DISABLE_QUIRKS 116
#define KVM_CAP_X86_SMM 117
#define KVM_CAP_MULTI_ADDRESS_SPACE 118
#define KVM_CAP_GUEST_DEBUG_HW_BPS 119
#define KVM_CAP_GUEST_DEBUG_HW_WPS 120
#define KVM_CAP_SPLIT_IRQCHIP 121
#define KVM_CAP_IOEVENTFD_ANY_LENGTH 122
#define KVM_CAP_HYPERV_SYNIC 123
#define KVM_CAP_S390_RI 124
#define KVM_CAP_SPAPR_TCE_64 125
#define KVM_CAP_ARM_PMU_V3 126
#define KVM_CAP_VCPU_ATTRIBUTES 127
#define KVM_CAP_MAX_VCPU_ID 128
#define KVM_CAP_X2APIC_API 129
#define KVM_CAP_S390_USER_INSTR0 130
#define KVM_CAP_MSI_DEVID 131
#define KVM_CAP_PPC_HTM 132
#define KVM_CAP_SPAPR_RESIZE_HPT 133
#define KVM_CAP_PPC_MMU_RADIX 134
#define KVM_CAP_PPC_MMU_HASH_V3 135
#define KVM_CAP_IMMEDIATE_EXIT 136
#define KVM_CAP_MIPS_VZ 137
#define KVM_CAP_MIPS_TE 138
#define KVM_CAP_MIPS_64BIT 139
#define KVM_CAP_S390_GS 140
#define KVM_CAP_S390_AIS 141
#define KVM_CAP_SPAPR_TCE_VFIO 142
#define KVM_CAP_X86_DISABLE_EXITS 143
#define KVM_CAP_ARM_USER_IRQ 144
#define KVM_CAP_S390_CMMA_MIGRATION 145
#define KVM_CAP_PPC_FWNMI 146
#define KVM_CAP_PPC_SMT_POSSIBLE 147
#define KVM_CAP_HYPERV_SYNIC2 148
#define KVM_CAP_HYPERV_VP_INDEX 149
#define KVM_CAP_S390_AIS_MIGRATION 150
#define KVM_CAP_PPC_GET_CPU_CHAR 151
#define KVM_CAP_S390_BPB 152
#define KVM_CAP_GET_MSR_FEATURES 153
#define KVM_CAP_HYPERV_EVENTFD 154
#define KVM_CAP_HYPERV_TLBFLUSH 155
#define KVM_CAP_S390_HPAGE_1M 156
#define KVM_CAP_NESTED_STATE 157
#define KVM_CAP_ARM_INJECT_SERROR_ESR 158
#define KVM_CAP_MSR_PLATFORM_INFO 159
#define KVM_CAP_PPC_NESTED_HV 160
#define KVM_CAP_HYPERV_SEND_IPI 161
#define KVM_CAP_COALESCED_PIO 162
#define KVM_CAP_HYPERV_ENLIGHTENED_VMCS 163
#define KVM_CAP_EXCEPTION_PAYLOAD 164
#define KVM_CAP_ARM_VM_IPA_SIZE 165
#define KVM_CAP_MANUAL_DIRTY_LOG_PROTECT 166
#define KVM_CAP_HYPERV_CPUID 167
#define KVM_CAP_MANUAL_DIRTY_LOG_PROTECT2 168
#define KVM_CAP_PPC_IRQ_XIVE 169
#define KVM_CAP_ARM_SVE 170
#define KVM_CAP_ARM_PTRAUTH_ADDRESS 171
#define KVM_CAP_ARM_PTRAUTH_GENERIC 172
#define KVM_CAP_PMU_EVENT_FILTER 173
#define KVM_CAP_ARM_IRQ_LINE_LAYOUT_2 174
#define KVM_CAP_HYPERV_DIRECT_TLBFLUSH 175
#define KVM_CAP_PPC_GUEST_DEBUG_SSTEP 176
#define KVM_CAP_ARM_NISV_TO_USER 177
#define KVM_CAP_ARM_INJECT_EXT_DABT 178
#define KVM_CAP_S390_VCPU_RESETS 179
#define KVM_CAP_S390_PROTECTED 180
#define KVM_CAP_PPC_SECURE_GUEST 181
#define KVM_CAP_HALT_POLL 182
#define KVM_CAP_ASYNC_PF_INT 183
#define KVM_CAP_LAST_CPU 184
#define KVM_CAP_SMALLER_MAXPHYADDR 185
#define KVM_CAP_S390_DIAG318 186
#define KVM_CAP_STEAL_TIME 187
#define KVM_CAP_X86_USER_SPACE_MSR 188
#define KVM_CAP_X86_MSR_FILTER 189
#define KVM_CAP_ENFORCE_PV_FEATURE_CPUID 190
#ifdef KVM_CAP_IRQ_ROUTING
struct kvm_irq_routing_irqchip {
  __u32 irqchip;
  __u32 pin;
};
struct kvm_irq_routing_msi {
  __u32 address_lo;
  __u32 address_hi;
  __u32 data;
  union {
    __u32 pad;
    __u32 devid;
  };
};
struct kvm_irq_routing_s390_adapter {
  __u64 ind_addr;
  __u64 summary_addr;
  __u64 ind_offset;
  __u32 summary_offset;
  __u32 adapter_id;
};
struct kvm_irq_routing_hv_sint {
  __u32 vcpu;
  __u32 sint;
};
#define KVM_IRQ_ROUTING_IRQCHIP 1
#define KVM_IRQ_ROUTING_MSI 2
#define KVM_IRQ_ROUTING_S390_ADAPTER 3
#define KVM_IRQ_ROUTING_HV_SINT 4
struct kvm_irq_routing_entry {
  __u32 gsi;
  __u32 type;
  __u32 flags;
  __u32 pad;
  union {
    struct kvm_irq_routing_irqchip irqchip;
    struct kvm_irq_routing_msi msi;
    struct kvm_irq_routing_s390_adapter adapter;
    struct kvm_irq_routing_hv_sint hv_sint;
    __u32 pad[8];
  } u;
};
struct kvm_irq_routing {
  __u32 nr;
  __u32 flags;
  struct kvm_irq_routing_entry entries[0];
};
#endif
#ifdef KVM_CAP_MCE
struct kvm_x86_mce {
  __u64 status;
  __u64 addr;
  __u64 misc;
  __u64 mcg_status;
  __u8 bank;
  __u8 pad1[7];
  __u64 pad2[3];
};
#endif
#ifdef KVM_CAP_XEN_HVM
struct kvm_xen_hvm_config {
  __u32 flags;
  __u32 msr;
  __u64 blob_addr_32;
  __u64 blob_addr_64;
  __u8 blob_size_32;
  __u8 blob_size_64;
  __u8 pad2[30];
};
#endif
#define KVM_IRQFD_FLAG_DEASSIGN (1 << 0)
#define KVM_IRQFD_FLAG_RESAMPLE (1 << 1)
struct kvm_irqfd {
  __u32 fd;
  __u32 gsi;
  __u32 flags;
  __u32 resamplefd;
  __u8 pad[16];
};
#define KVM_CLOCK_TSC_STABLE 2
struct kvm_clock_data {
  __u64 clock;
  __u32 flags;
  __u32 pad[9];
};
#define KVM_MMU_FSL_BOOKE_NOHV 0
#define KVM_MMU_FSL_BOOKE_HV 1
struct kvm_config_tlb {
  __u64 params;
  __u64 array;
  __u32 mmu_type;
  __u32 array_len;
};
struct kvm_dirty_tlb {
  __u64 bitmap;
  __u32 num_dirty;
};
#define KVM_REG_ARCH_MASK 0xff00000000000000ULL
#define KVM_REG_GENERIC 0x0000000000000000ULL
#define KVM_REG_PPC 0x1000000000000000ULL
#define KVM_REG_X86 0x2000000000000000ULL
#define KVM_REG_IA64 0x3000000000000000ULL
#define KVM_REG_ARM 0x4000000000000000ULL
#define KVM_REG_S390 0x5000000000000000ULL
#define KVM_REG_ARM64 0x6000000000000000ULL
#define KVM_REG_MIPS 0x7000000000000000ULL
#define KVM_REG_RISCV 0x8000000000000000ULL
#define KVM_REG_SIZE_SHIFT 52
#define KVM_REG_SIZE_MASK 0x00f0000000000000ULL
#define KVM_REG_SIZE_U8 0x0000000000000000ULL
#define KVM_REG_SIZE_U16 0x0010000000000000ULL
#define KVM_REG_SIZE_U32 0x0020000000000000ULL
#define KVM_REG_SIZE_U64 0x0030000000000000ULL
#define KVM_REG_SIZE_U128 0x0040000000000000ULL
#define KVM_REG_SIZE_U256 0x0050000000000000ULL
#define KVM_REG_SIZE_U512 0x0060000000000000ULL
#define KVM_REG_SIZE_U1024 0x0070000000000000ULL
#define KVM_REG_SIZE_U2048 0x0080000000000000ULL
struct kvm_reg_list {
  __u64 n;
  __u64 reg[0];
};
struct kvm_one_reg {
  __u64 id;
  __u64 addr;
};
#define KVM_MSI_VALID_DEVID (1U << 0)
struct kvm_msi {
  __u32 address_lo;
  __u32 address_hi;
  __u32 data;
  __u32 flags;
  __u32 devid;
  __u8 pad[12];
};
struct kvm_arm_device_addr {
  __u64 id;
  __u64 addr;
};
#define KVM_CREATE_DEVICE_TEST 1
struct kvm_create_device {
  __u32 type;
  __u32 fd;
  __u32 flags;
};
struct kvm_device_attr {
  __u32 flags;
  __u32 group;
  __u64 attr;
  __u64 addr;
};
#define KVM_DEV_VFIO_GROUP 1
#define KVM_DEV_VFIO_GROUP_ADD 1
#define KVM_DEV_VFIO_GROUP_DEL 2
#define KVM_DEV_VFIO_GROUP_SET_SPAPR_TCE 3
enum kvm_device_type {
  KVM_DEV_TYPE_FSL_MPIC_20 = 1,
#define KVM_DEV_TYPE_FSL_MPIC_20 KVM_DEV_TYPE_FSL_MPIC_20
  KVM_DEV_TYPE_FSL_MPIC_42,
#define KVM_DEV_TYPE_FSL_MPIC_42 KVM_DEV_TYPE_FSL_MPIC_42
  KVM_DEV_TYPE_XICS,
#define KVM_DEV_TYPE_XICS KVM_DEV_TYPE_XICS
  KVM_DEV_TYPE_VFIO,
#define KVM_DEV_TYPE_VFIO KVM_DEV_TYPE_VFIO
  KVM_DEV_TYPE_ARM_VGIC_V2,
#define KVM_DEV_TYPE_ARM_VGIC_V2 KVM_DEV_TYPE_ARM_VGIC_V2
  KVM_DEV_TYPE_FLIC,
#define KVM_DEV_TYPE_FLIC KVM_DEV_TYPE_FLIC
  KVM_DEV_TYPE_ARM_VGIC_V3,
#define KVM_DEV_TYPE_ARM_VGIC_V3 KVM_DEV_TYPE_ARM_VGIC_V3
  KVM_DEV_TYPE_ARM_VGIC_ITS,
#define KVM_DEV_TYPE_ARM_VGIC_ITS KVM_DEV_TYPE_ARM_VGIC_ITS
  KVM_DEV_TYPE_XIVE,
#define KVM_DEV_TYPE_XIVE KVM_DEV_TYPE_XIVE
  KVM_DEV_TYPE_ARM_PV_TIME,
#define KVM_DEV_TYPE_ARM_PV_TIME KVM_DEV_TYPE_ARM_PV_TIME
  KVM_DEV_TYPE_MAX,
};
struct kvm_vfio_spapr_tce {
  __s32 groupfd;
  __s32 tablefd;
};
#define KVM_SET_MEMORY_REGION _IOW(KVMIO, 0x40, struct kvm_memory_region)
#define KVM_CREATE_VCPU _IO(KVMIO, 0x41)
#define KVM_GET_DIRTY_LOG _IOW(KVMIO, 0x42, struct kvm_dirty_log)
#define KVM_SET_MEMORY_ALIAS _IOW(KVMIO, 0x43, struct kvm_memory_alias)
#define KVM_SET_NR_MMU_PAGES _IO(KVMIO, 0x44)
#define KVM_GET_NR_MMU_PAGES _IO(KVMIO, 0x45)
#define KVM_SET_USER_MEMORY_REGION _IOW(KVMIO, 0x46, struct kvm_userspace_memory_region)
#define KVM_SET_TSS_ADDR _IO(KVMIO, 0x47)
#define KVM_SET_IDENTITY_MAP_ADDR _IOW(KVMIO, 0x48, __u64)
struct kvm_s390_ucas_mapping {
  __u64 user_addr;
  __u64 vcpu_addr;
  __u64 length;
};
#define KVM_S390_UCAS_MAP _IOW(KVMIO, 0x50, struct kvm_s390_ucas_mapping)
#define KVM_S390_UCAS_UNMAP _IOW(KVMIO, 0x51, struct kvm_s390_ucas_mapping)
#define KVM_S390_VCPU_FAULT _IOW(KVMIO, 0x52, unsigned long)
#define KVM_CREATE_IRQCHIP _IO(KVMIO, 0x60)
#define KVM_IRQ_LINE _IOW(KVMIO, 0x61, struct kvm_irq_level)
#define KVM_GET_IRQCHIP _IOWR(KVMIO, 0x62, struct kvm_irqchip)
#define KVM_SET_IRQCHIP _IOR(KVMIO, 0x63, struct kvm_irqchip)
#define KVM_CREATE_PIT _IO(KVMIO, 0x64)
#define KVM_GET_PIT _IOWR(KVMIO, 0x65, struct kvm_pit_state)
#define KVM_SET_PIT _IOR(KVMIO, 0x66, struct kvm_pit_state)
#define KVM_IRQ_LINE_STATUS _IOWR(KVMIO, 0x67, struct kvm_irq_level)
#define KVM_REGISTER_COALESCED_MMIO _IOW(KVMIO, 0x67, struct kvm_coalesced_mmio_zone)
#define KVM_UNREGISTER_COALESCED_MMIO _IOW(KVMIO, 0x68, struct kvm_coalesced_mmio_zone)
#define KVM_ASSIGN_PCI_DEVICE _IOR(KVMIO, 0x69, struct kvm_assigned_pci_dev)
#define KVM_SET_GSI_ROUTING _IOW(KVMIO, 0x6a, struct kvm_irq_routing)
#define KVM_ASSIGN_IRQ __KVM_DEPRECATED_VM_R_0x70
#define KVM_ASSIGN_DEV_IRQ _IOW(KVMIO, 0x70, struct kvm_assigned_irq)
#define KVM_REINJECT_CONTROL _IO(KVMIO, 0x71)
#define KVM_DEASSIGN_PCI_DEVICE _IOW(KVMIO, 0x72, struct kvm_assigned_pci_dev)
#define KVM_ASSIGN_SET_MSIX_NR _IOW(KVMIO, 0x73, struct kvm_assigned_msix_nr)
#define KVM_ASSIGN_SET_MSIX_ENTRY _IOW(KVMIO, 0x74, struct kvm_assigned_msix_entry)
#define KVM_DEASSIGN_DEV_IRQ _IOW(KVMIO, 0x75, struct kvm_assigned_irq)
#define KVM_IRQFD _IOW(KVMIO, 0x76, struct kvm_irqfd)
#define KVM_CREATE_PIT2 _IOW(KVMIO, 0x77, struct kvm_pit_config)
#define KVM_SET_BOOT_CPU_ID _IO(KVMIO, 0x78)
#define KVM_IOEVENTFD _IOW(KVMIO, 0x79, struct kvm_ioeventfd)
#define KVM_XEN_HVM_CONFIG _IOW(KVMIO, 0x7a, struct kvm_xen_hvm_config)
#define KVM_SET_CLOCK _IOW(KVMIO, 0x7b, struct kvm_clock_data)
#define KVM_GET_CLOCK _IOR(KVMIO, 0x7c, struct kvm_clock_data)
#define KVM_GET_PIT2 _IOR(KVMIO, 0x9f, struct kvm_pit_state2)
#define KVM_SET_PIT2 _IOW(KVMIO, 0xa0, struct kvm_pit_state2)
#define KVM_PPC_GET_PVINFO _IOW(KVMIO, 0xa1, struct kvm_ppc_pvinfo)
#define KVM_SET_TSC_KHZ _IO(KVMIO, 0xa2)
#define KVM_GET_TSC_KHZ _IO(KVMIO, 0xa3)
#define KVM_ASSIGN_SET_INTX_MASK _IOW(KVMIO, 0xa4, struct kvm_assigned_pci_dev)
#define KVM_SIGNAL_MSI _IOW(KVMIO, 0xa5, struct kvm_msi)
#define KVM_PPC_GET_SMMU_INFO _IOR(KVMIO, 0xa6, struct kvm_ppc_smmu_info)
#define KVM_PPC_ALLOCATE_HTAB _IOWR(KVMIO, 0xa7, __u32)
#define KVM_CREATE_SPAPR_TCE _IOW(KVMIO, 0xa8, struct kvm_create_spapr_tce)
#define KVM_CREATE_SPAPR_TCE_64 _IOW(KVMIO, 0xa8, struct kvm_create_spapr_tce_64)
#define KVM_ALLOCATE_RMA _IOR(KVMIO, 0xa9, struct kvm_allocate_rma)
#define KVM_PPC_GET_HTAB_FD _IOW(KVMIO, 0xaa, struct kvm_get_htab_fd)
#define KVM_ARM_SET_DEVICE_ADDR _IOW(KVMIO, 0xab, struct kvm_arm_device_addr)
#define KVM_PPC_RTAS_DEFINE_TOKEN _IOW(KVMIO, 0xac, struct kvm_rtas_token_args)
#define KVM_PPC_RESIZE_HPT_PREPARE _IOR(KVMIO, 0xad, struct kvm_ppc_resize_hpt)
#define KVM_PPC_RESIZE_HPT_COMMIT _IOR(KVMIO, 0xae, struct kvm_ppc_resize_hpt)
#define KVM_PPC_CONFIGURE_V3_MMU _IOW(KVMIO, 0xaf, struct kvm_ppc_mmuv3_cfg)
#define KVM_PPC_GET_RMMU_INFO _IOW(KVMIO, 0xb0, struct kvm_ppc_rmmu_info)
#define KVM_PPC_GET_CPU_CHAR _IOR(KVMIO, 0xb1, struct kvm_ppc_cpu_char)
#define KVM_SET_PMU_EVENT_FILTER _IOW(KVMIO, 0xb2, struct kvm_pmu_event_filter)
#define KVM_PPC_SVM_OFF _IO(KVMIO, 0xb3)
#define KVM_CREATE_DEVICE _IOWR(KVMIO, 0xe0, struct kvm_create_device)
#define KVM_SET_DEVICE_ATTR _IOW(KVMIO, 0xe1, struct kvm_device_attr)
#define KVM_GET_DEVICE_ATTR _IOW(KVMIO, 0xe2, struct kvm_device_attr)
#define KVM_HAS_DEVICE_ATTR _IOW(KVMIO, 0xe3, struct kvm_device_attr)
#define KVM_RUN _IO(KVMIO, 0x80)
#define KVM_GET_REGS _IOR(KVMIO, 0x81, struct kvm_regs)
#define KVM_SET_REGS _IOW(KVMIO, 0x82, struct kvm_regs)
#define KVM_GET_SREGS _IOR(KVMIO, 0x83, struct kvm_sregs)
#define KVM_SET_SREGS _IOW(KVMIO, 0x84, struct kvm_sregs)
#define KVM_TRANSLATE _IOWR(KVMIO, 0x85, struct kvm_translation)
#define KVM_INTERRUPT _IOW(KVMIO, 0x86, struct kvm_interrupt)
#define KVM_DEBUG_GUEST __KVM_DEPRECATED_VCPU_W_0x87
#define KVM_GET_MSRS _IOWR(KVMIO, 0x88, struct kvm_msrs)
#define KVM_SET_MSRS _IOW(KVMIO, 0x89, struct kvm_msrs)
#define KVM_SET_CPUID _IOW(KVMIO, 0x8a, struct kvm_cpuid)
#define KVM_SET_SIGNAL_MASK _IOW(KVMIO, 0x8b, struct kvm_signal_mask)
#define KVM_GET_FPU _IOR(KVMIO, 0x8c, struct kvm_fpu)
#define KVM_SET_FPU _IOW(KVMIO, 0x8d, struct kvm_fpu)
#define KVM_GET_LAPIC _IOR(KVMIO, 0x8e, struct kvm_lapic_state)
#define KVM_SET_LAPIC _IOW(KVMIO, 0x8f, struct kvm_lapic_state)
#define KVM_SET_CPUID2 _IOW(KVMIO, 0x90, struct kvm_cpuid2)
#define KVM_GET_CPUID2 _IOWR(KVMIO, 0x91, struct kvm_cpuid2)
#define KVM_TPR_ACCESS_REPORTING _IOWR(KVMIO, 0x92, struct kvm_tpr_access_ctl)
#define KVM_SET_VAPIC_ADDR _IOW(KVMIO, 0x93, struct kvm_vapic_addr)
#define KVM_S390_INTERRUPT _IOW(KVMIO, 0x94, struct kvm_s390_interrupt)
#define KVM_S390_STORE_STATUS_NOADDR (- 1ul)
#define KVM_S390_STORE_STATUS_PREFIXED (- 2ul)
#define KVM_S390_STORE_STATUS _IOW(KVMIO, 0x95, unsigned long)
#define KVM_S390_SET_INITIAL_PSW _IOW(KVMIO, 0x96, struct kvm_s390_psw)
#define KVM_S390_INITIAL_RESET _IO(KVMIO, 0x97)
#define KVM_GET_MP_STATE _IOR(KVMIO, 0x98, struct kvm_mp_state)
#define KVM_SET_MP_STATE _IOW(KVMIO, 0x99, struct kvm_mp_state)
#define KVM_NMI _IO(KVMIO, 0x9a)
#define KVM_SET_GUEST_DEBUG _IOW(KVMIO, 0x9b, struct kvm_guest_debug)
#define KVM_X86_SETUP_MCE _IOW(KVMIO, 0x9c, __u64)
#define KVM_X86_GET_MCE_CAP_SUPPORTED _IOR(KVMIO, 0x9d, __u64)
#define KVM_X86_SET_MCE _IOW(KVMIO, 0x9e, struct kvm_x86_mce)
#define KVM_GET_VCPU_EVENTS _IOR(KVMIO, 0x9f, struct kvm_vcpu_events)
#define KVM_SET_VCPU_EVENTS _IOW(KVMIO, 0xa0, struct kvm_vcpu_events)
#define KVM_GET_DEBUGREGS _IOR(KVMIO, 0xa1, struct kvm_debugregs)
#define KVM_SET_DEBUGREGS _IOW(KVMIO, 0xa2, struct kvm_debugregs)
#define KVM_ENABLE_CAP _IOW(KVMIO, 0xa3, struct kvm_enable_cap)
#define KVM_GET_XSAVE _IOR(KVMIO, 0xa4, struct kvm_xsave)
#define KVM_SET_XSAVE _IOW(KVMIO, 0xa5, struct kvm_xsave)
#define KVM_GET_XCRS _IOR(KVMIO, 0xa6, struct kvm_xcrs)
#define KVM_SET_XCRS _IOW(KVMIO, 0xa7, struct kvm_xcrs)
#define KVM_DIRTY_TLB _IOW(KVMIO, 0xaa, struct kvm_dirty_tlb)
#define KVM_GET_ONE_REG _IOW(KVMIO, 0xab, struct kvm_one_reg)
#define KVM_SET_ONE_REG _IOW(KVMIO, 0xac, struct kvm_one_reg)
#define KVM_KVMCLOCK_CTRL _IO(KVMIO, 0xad)
#define KVM_ARM_VCPU_INIT _IOW(KVMIO, 0xae, struct kvm_vcpu_init)
#define KVM_ARM_PREFERRED_TARGET _IOR(KVMIO, 0xaf, struct kvm_vcpu_init)
#define KVM_GET_REG_LIST _IOWR(KVMIO, 0xb0, struct kvm_reg_list)
#define KVM_S390_MEM_OP _IOW(KVMIO, 0xb1, struct kvm_s390_mem_op)
#define KVM_S390_GET_SKEYS _IOW(KVMIO, 0xb2, struct kvm_s390_skeys)
#define KVM_S390_SET_SKEYS _IOW(KVMIO, 0xb3, struct kvm_s390_skeys)
#define KVM_S390_IRQ _IOW(KVMIO, 0xb4, struct kvm_s390_irq)
#define KVM_S390_SET_IRQ_STATE _IOW(KVMIO, 0xb5, struct kvm_s390_irq_state)
#define KVM_S390_GET_IRQ_STATE _IOW(KVMIO, 0xb6, struct kvm_s390_irq_state)
#define KVM_SMI _IO(KVMIO, 0xb7)
#define KVM_S390_GET_CMMA_BITS _IOWR(KVMIO, 0xb8, struct kvm_s390_cmma_log)
#define KVM_S390_SET_CMMA_BITS _IOW(KVMIO, 0xb9, struct kvm_s390_cmma_log)
#define KVM_MEMORY_ENCRYPT_OP _IOWR(KVMIO, 0xba, unsigned long)
struct kvm_enc_region {
  __u64 addr;
  __u64 size;
};
#define KVM_MEMORY_ENCRYPT_REG_REGION _IOR(KVMIO, 0xbb, struct kvm_enc_region)
#define KVM_MEMORY_ENCRYPT_UNREG_REGION _IOR(KVMIO, 0xbc, struct kvm_enc_region)
#define KVM_HYPERV_EVENTFD _IOW(KVMIO, 0xbd, struct kvm_hyperv_eventfd)
#define KVM_GET_NESTED_STATE _IOWR(KVMIO, 0xbe, struct kvm_nested_state)
#define KVM_SET_NESTED_STATE _IOW(KVMIO, 0xbf, struct kvm_nested_state)
#define KVM_CLEAR_DIRTY_LOG _IOWR(KVMIO, 0xc0, struct kvm_clear_dirty_log)
#define KVM_GET_SUPPORTED_HV_CPUID _IOWR(KVMIO, 0xc1, struct kvm_cpuid2)
#define KVM_ARM_VCPU_FINALIZE _IOW(KVMIO, 0xc2, int)
#define KVM_S390_NORMAL_RESET _IO(KVMIO, 0xc3)
#define KVM_S390_CLEAR_RESET _IO(KVMIO, 0xc4)
struct kvm_s390_pv_sec_parm {
  __u64 origin;
  __u64 length;
};
struct kvm_s390_pv_unp {
  __u64 addr;
  __u64 size;
  __u64 tweak;
};
enum pv_cmd_id {
  KVM_PV_ENABLE,
  KVM_PV_DISABLE,
  KVM_PV_SET_SEC_PARMS,
  KVM_PV_UNPACK,
  KVM_PV_VERIFY,
  KVM_PV_PREP_RESET,
  KVM_PV_UNSHARE_ALL,
};
struct kvm_pv_cmd {
  __u32 cmd;
  __u16 rc;
  __u16 rrc;
  __u64 data;
  __u32 flags;
  __u32 reserved[3];
};
#define KVM_S390_PV_COMMAND _IOWR(KVMIO, 0xc5, struct kvm_pv_cmd)
#define KVM_X86_SET_MSR_FILTER _IOW(KVMIO, 0xc6, struct kvm_msr_filter)
enum sev_cmd_id {
  KVM_SEV_INIT = 0,
  KVM_SEV_ES_INIT,
  KVM_SEV_LAUNCH_START,
  KVM_SEV_LAUNCH_UPDATE_DATA,
  KVM_SEV_LAUNCH_UPDATE_VMSA,
  KVM_SEV_LAUNCH_SECRET,
  KVM_SEV_LAUNCH_MEASURE,
  KVM_SEV_LAUNCH_FINISH,
  KVM_SEV_SEND_START,
  KVM_SEV_SEND_UPDATE_DATA,
  KVM_SEV_SEND_UPDATE_VMSA,
  KVM_SEV_SEND_FINISH,
  KVM_SEV_RECEIVE_START,
  KVM_SEV_RECEIVE_UPDATE_DATA,
  KVM_SEV_RECEIVE_UPDATE_VMSA,
  KVM_SEV_RECEIVE_FINISH,
  KVM_SEV_GUEST_STATUS,
  KVM_SEV_DBG_DECRYPT,
  KVM_SEV_DBG_ENCRYPT,
  KVM_SEV_CERT_EXPORT,
  KVM_SEV_NR_MAX,
};
struct kvm_sev_cmd {
  __u32 id;
  __u64 data;
  __u32 error;
  __u32 sev_fd;
};
struct kvm_sev_launch_start {
  __u32 handle;
  __u32 policy;
  __u64 dh_uaddr;
  __u32 dh_len;
  __u64 session_uaddr;
  __u32 session_len;
};
struct kvm_sev_launch_update_data {
  __u64 uaddr;
  __u32 len;
};
struct kvm_sev_launch_secret {
  __u64 hdr_uaddr;
  __u32 hdr_len;
  __u64 guest_uaddr;
  __u32 guest_len;
  __u64 trans_uaddr;
  __u32 trans_len;
};
struct kvm_sev_launch_measure {
  __u64 uaddr;
  __u32 len;
};
struct kvm_sev_guest_status {
  __u32 handle;
  __u32 policy;
  __u32 state;
};
struct kvm_sev_dbg {
  __u64 src_uaddr;
  __u64 dst_uaddr;
  __u32 len;
};
#define KVM_DEV_ASSIGN_ENABLE_IOMMU (1 << 0)
#define KVM_DEV_ASSIGN_PCI_2_3 (1 << 1)
#define KVM_DEV_ASSIGN_MASK_INTX (1 << 2)
struct kvm_assigned_pci_dev {
  __u32 assigned_dev_id;
  __u32 busnr;
  __u32 devfn;
  __u32 flags;
  __u32 segnr;
  union {
    __u32 reserved[11];
  };
};
#define KVM_DEV_IRQ_HOST_INTX (1 << 0)
#define KVM_DEV_IRQ_HOST_MSI (1 << 1)
#define KVM_DEV_IRQ_HOST_MSIX (1 << 2)
#define KVM_DEV_IRQ_GUEST_INTX (1 << 8)
#define KVM_DEV_IRQ_GUEST_MSI (1 << 9)
#define KVM_DEV_IRQ_GUEST_MSIX (1 << 10)
#define KVM_DEV_IRQ_HOST_MASK 0x00ff
#define KVM_DEV_IRQ_GUEST_MASK 0xff00
struct kvm_assigned_irq {
  __u32 assigned_dev_id;
  __u32 host_irq;
  __u32 guest_irq;
  __u32 flags;
  union {
    __u32 reserved[12];
  };
};
struct kvm_assigned_msix_nr {
  __u32 assigned_dev_id;
  __u16 entry_nr;
  __u16 padding;
};
#define KVM_MAX_MSIX_PER_DEV 256
struct kvm_assigned_msix_entry {
  __u32 assigned_dev_id;
  __u32 gsi;
  __u16 entry;
  __u16 padding[3];
};
#define KVM_X2APIC_API_USE_32BIT_IDS (1ULL << 0)
#define KVM_X2APIC_API_DISABLE_BROADCAST_QUIRK (1ULL << 1)
#define KVM_ARM_DEV_EL1_VTIMER (1 << 0)
#define KVM_ARM_DEV_EL1_PTIMER (1 << 1)
#define KVM_ARM_DEV_PMU (1 << 2)
struct kvm_hyperv_eventfd {
  __u32 conn_id;
  __s32 fd;
  __u32 flags;
  __u32 padding[3];
};
#define KVM_HYPERV_CONN_ID_MASK 0x00ffffff
#define KVM_HYPERV_EVENTFD_DEASSIGN (1 << 0)
#define KVM_DIRTY_LOG_MANUAL_PROTECT_ENABLE (1 << 0)
#define KVM_DIRTY_LOG_INITIALLY_SET (1 << 1)
#endif