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
#ifndef KFD_IOCTL_H_INCLUDED
#define KFD_IOCTL_H_INCLUDED
#include <drm/drm.h>
#include <linux/ioctl.h>
#define KFD_IOCTL_MAJOR_VERSION 1
#define KFD_IOCTL_MINOR_VERSION 3
struct kfd_ioctl_get_version_args {
  __u32 major_version;
  __u32 minor_version;
};
#define KFD_IOC_QUEUE_TYPE_COMPUTE 0x0
#define KFD_IOC_QUEUE_TYPE_SDMA 0x1
#define KFD_IOC_QUEUE_TYPE_COMPUTE_AQL 0x2
#define KFD_IOC_QUEUE_TYPE_SDMA_XGMI 0x3
#define KFD_MAX_QUEUE_PERCENTAGE 100
#define KFD_MAX_QUEUE_PRIORITY 15
struct kfd_ioctl_create_queue_args {
  __u64 ring_base_address;
  __u64 write_pointer_address;
  __u64 read_pointer_address;
  __u64 doorbell_offset;
  __u32 ring_size;
  __u32 gpu_id;
  __u32 queue_type;
  __u32 queue_percentage;
  __u32 queue_priority;
  __u32 queue_id;
  __u64 eop_buffer_address;
  __u64 eop_buffer_size;
  __u64 ctx_save_restore_address;
  __u32 ctx_save_restore_size;
  __u32 ctl_stack_size;
};
struct kfd_ioctl_destroy_queue_args {
  __u32 queue_id;
  __u32 pad;
};
struct kfd_ioctl_update_queue_args {
  __u64 ring_base_address;
  __u32 queue_id;
  __u32 ring_size;
  __u32 queue_percentage;
  __u32 queue_priority;
};
struct kfd_ioctl_set_cu_mask_args {
  __u32 queue_id;
  __u32 num_cu_mask;
  __u64 cu_mask_ptr;
};
struct kfd_ioctl_get_queue_wave_state_args {
  __u64 ctl_stack_address;
  __u32 ctl_stack_used_size;
  __u32 save_area_used_size;
  __u32 queue_id;
  __u32 pad;
};
#define KFD_IOC_CACHE_POLICY_COHERENT 0
#define KFD_IOC_CACHE_POLICY_NONCOHERENT 1
struct kfd_ioctl_set_memory_policy_args {
  __u64 alternate_aperture_base;
  __u64 alternate_aperture_size;
  __u32 gpu_id;
  __u32 default_policy;
  __u32 alternate_policy;
  __u32 pad;
};
struct kfd_ioctl_get_clock_counters_args {
  __u64 gpu_clock_counter;
  __u64 cpu_clock_counter;
  __u64 system_clock_counter;
  __u64 system_clock_freq;
  __u32 gpu_id;
  __u32 pad;
};
struct kfd_process_device_apertures {
  __u64 lds_base;
  __u64 lds_limit;
  __u64 scratch_base;
  __u64 scratch_limit;
  __u64 gpuvm_base;
  __u64 gpuvm_limit;
  __u32 gpu_id;
  __u32 pad;
};
#define NUM_OF_SUPPORTED_GPUS 7
struct kfd_ioctl_get_process_apertures_args {
  struct kfd_process_device_apertures process_apertures[NUM_OF_SUPPORTED_GPUS];
  __u32 num_of_nodes;
  __u32 pad;
};
struct kfd_ioctl_get_process_apertures_new_args {
  __u64 kfd_process_device_apertures_ptr;
  __u32 num_of_nodes;
  __u32 pad;
};
#define MAX_ALLOWED_NUM_POINTS 100
#define MAX_ALLOWED_AW_BUFF_SIZE 4096
#define MAX_ALLOWED_WAC_BUFF_SIZE 128
struct kfd_ioctl_dbg_register_args {
  __u32 gpu_id;
  __u32 pad;
};
struct kfd_ioctl_dbg_unregister_args {
  __u32 gpu_id;
  __u32 pad;
};
struct kfd_ioctl_dbg_address_watch_args {
  __u64 content_ptr;
  __u32 gpu_id;
  __u32 buf_size_in_bytes;
};
struct kfd_ioctl_dbg_wave_control_args {
  __u64 content_ptr;
  __u32 gpu_id;
  __u32 buf_size_in_bytes;
};
#define KFD_IOC_EVENT_SIGNAL 0
#define KFD_IOC_EVENT_NODECHANGE 1
#define KFD_IOC_EVENT_DEVICESTATECHANGE 2
#define KFD_IOC_EVENT_HW_EXCEPTION 3
#define KFD_IOC_EVENT_SYSTEM_EVENT 4
#define KFD_IOC_EVENT_DEBUG_EVENT 5
#define KFD_IOC_EVENT_PROFILE_EVENT 6
#define KFD_IOC_EVENT_QUEUE_EVENT 7
#define KFD_IOC_EVENT_MEMORY 8
#define KFD_IOC_WAIT_RESULT_COMPLETE 0
#define KFD_IOC_WAIT_RESULT_TIMEOUT 1
#define KFD_IOC_WAIT_RESULT_FAIL 2
#define KFD_SIGNAL_EVENT_LIMIT 4096
#define KFD_HW_EXCEPTION_WHOLE_GPU_RESET 0
#define KFD_HW_EXCEPTION_PER_ENGINE_RESET 1
#define KFD_HW_EXCEPTION_GPU_HANG 0
#define KFD_HW_EXCEPTION_ECC 1
#define KFD_MEM_ERR_NO_RAS 0
#define KFD_MEM_ERR_SRAM_ECC 1
#define KFD_MEM_ERR_POISON_CONSUMED 2
#define KFD_MEM_ERR_GPU_HANG 3
struct kfd_ioctl_create_event_args {
  __u64 event_page_offset;
  __u32 event_trigger_data;
  __u32 event_type;
  __u32 auto_reset;
  __u32 node_id;
  __u32 event_id;
  __u32 event_slot_index;
};
struct kfd_ioctl_destroy_event_args {
  __u32 event_id;
  __u32 pad;
};
struct kfd_ioctl_set_event_args {
  __u32 event_id;
  __u32 pad;
};
struct kfd_ioctl_reset_event_args {
  __u32 event_id;
  __u32 pad;
};
struct kfd_memory_exception_failure {
  __u32 NotPresent;
  __u32 ReadOnly;
  __u32 NoExecute;
  __u32 imprecise;
};
struct kfd_hsa_memory_exception_data {
  struct kfd_memory_exception_failure failure;
  __u64 va;
  __u32 gpu_id;
  __u32 ErrorType;
};
struct kfd_hsa_hw_exception_data {
  __u32 reset_type;
  __u32 reset_cause;
  __u32 memory_lost;
  __u32 gpu_id;
};
struct kfd_event_data {
  union {
    struct kfd_hsa_memory_exception_data memory_exception_data;
    struct kfd_hsa_hw_exception_data hw_exception_data;
  };
  __u64 kfd_event_data_ext;
  __u32 event_id;
  __u32 pad;
};
struct kfd_ioctl_wait_events_args {
  __u64 events_ptr;
  __u32 num_events;
  __u32 wait_for_all;
  __u32 timeout;
  __u32 wait_result;
};
struct kfd_ioctl_set_scratch_backing_va_args {
  __u64 va_addr;
  __u32 gpu_id;
  __u32 pad;
};
struct kfd_ioctl_get_tile_config_args {
  __u64 tile_config_ptr;
  __u64 macro_tile_config_ptr;
  __u32 num_tile_configs;
  __u32 num_macro_tile_configs;
  __u32 gpu_id;
  __u32 gb_addr_config;
  __u32 num_banks;
  __u32 num_ranks;
};
struct kfd_ioctl_set_trap_handler_args {
  __u64 tba_addr;
  __u64 tma_addr;
  __u32 gpu_id;
  __u32 pad;
};
struct kfd_ioctl_acquire_vm_args {
  __u32 drm_fd;
  __u32 gpu_id;
};
#define KFD_IOC_ALLOC_MEM_FLAGS_VRAM (1 << 0)
#define KFD_IOC_ALLOC_MEM_FLAGS_GTT (1 << 1)
#define KFD_IOC_ALLOC_MEM_FLAGS_USERPTR (1 << 2)
#define KFD_IOC_ALLOC_MEM_FLAGS_DOORBELL (1 << 3)
#define KFD_IOC_ALLOC_MEM_FLAGS_MMIO_REMAP (1 << 4)
#define KFD_IOC_ALLOC_MEM_FLAGS_WRITABLE (1 << 31)
#define KFD_IOC_ALLOC_MEM_FLAGS_EXECUTABLE (1 << 30)
#define KFD_IOC_ALLOC_MEM_FLAGS_PUBLIC (1 << 29)
#define KFD_IOC_ALLOC_MEM_FLAGS_NO_SUBSTITUTE (1 << 28)
#define KFD_IOC_ALLOC_MEM_FLAGS_AQL_QUEUE_MEM (1 << 27)
#define KFD_IOC_ALLOC_MEM_FLAGS_COHERENT (1 << 26)
struct kfd_ioctl_alloc_memory_of_gpu_args {
  __u64 va_addr;
  __u64 size;
  __u64 handle;
  __u64 mmap_offset;
  __u32 gpu_id;
  __u32 flags;
};
struct kfd_ioctl_free_memory_of_gpu_args {
  __u64 handle;
};
struct kfd_ioctl_map_memory_to_gpu_args {
  __u64 handle;
  __u64 device_ids_array_ptr;
  __u32 n_devices;
  __u32 n_success;
};
struct kfd_ioctl_unmap_memory_from_gpu_args {
  __u64 handle;
  __u64 device_ids_array_ptr;
  __u32 n_devices;
  __u32 n_success;
};
struct kfd_ioctl_alloc_queue_gws_args {
  __u32 queue_id;
  __u32 num_gws;
  __u32 first_gws;
  __u32 pad;
};
struct kfd_ioctl_get_dmabuf_info_args {
  __u64 size;
  __u64 metadata_ptr;
  __u32 metadata_size;
  __u32 gpu_id;
  __u32 flags;
  __u32 dmabuf_fd;
};
struct kfd_ioctl_import_dmabuf_args {
  __u64 va_addr;
  __u64 handle;
  __u32 gpu_id;
  __u32 dmabuf_fd;
};
enum kfd_smi_event {
  KFD_SMI_EVENT_NONE = 0,
  KFD_SMI_EVENT_VMFAULT = 1,
  KFD_SMI_EVENT_THERMAL_THROTTLE = 2,
  KFD_SMI_EVENT_GPU_PRE_RESET = 3,
  KFD_SMI_EVENT_GPU_POST_RESET = 4,
};
#define KFD_SMI_EVENT_MASK_FROM_INDEX(i) (1ULL << ((i) - 1))
struct kfd_ioctl_smi_events_args {
  __u32 gpuid;
  __u32 anon_fd;
};
enum kfd_mmio_remap {
  KFD_MMIO_REMAP_HDP_MEM_FLUSH_CNTL = 0,
  KFD_MMIO_REMAP_HDP_REG_FLUSH_CNTL = 4,
};
#define AMDKFD_IOCTL_BASE 'K'
#define AMDKFD_IO(nr) _IO(AMDKFD_IOCTL_BASE, nr)
#define AMDKFD_IOR(nr,type) _IOR(AMDKFD_IOCTL_BASE, nr, type)
#define AMDKFD_IOW(nr,type) _IOW(AMDKFD_IOCTL_BASE, nr, type)
#define AMDKFD_IOWR(nr,type) _IOWR(AMDKFD_IOCTL_BASE, nr, type)
#define AMDKFD_IOC_GET_VERSION AMDKFD_IOR(0x01, struct kfd_ioctl_get_version_args)
#define AMDKFD_IOC_CREATE_QUEUE AMDKFD_IOWR(0x02, struct kfd_ioctl_create_queue_args)
#define AMDKFD_IOC_DESTROY_QUEUE AMDKFD_IOWR(0x03, struct kfd_ioctl_destroy_queue_args)
#define AMDKFD_IOC_SET_MEMORY_POLICY AMDKFD_IOW(0x04, struct kfd_ioctl_set_memory_policy_args)
#define AMDKFD_IOC_GET_CLOCK_COUNTERS AMDKFD_IOWR(0x05, struct kfd_ioctl_get_clock_counters_args)
#define AMDKFD_IOC_GET_PROCESS_APERTURES AMDKFD_IOR(0x06, struct kfd_ioctl_get_process_apertures_args)
#define AMDKFD_IOC_UPDATE_QUEUE AMDKFD_IOW(0x07, struct kfd_ioctl_update_queue_args)
#define AMDKFD_IOC_CREATE_EVENT AMDKFD_IOWR(0x08, struct kfd_ioctl_create_event_args)
#define AMDKFD_IOC_DESTROY_EVENT AMDKFD_IOW(0x09, struct kfd_ioctl_destroy_event_args)
#define AMDKFD_IOC_SET_EVENT AMDKFD_IOW(0x0A, struct kfd_ioctl_set_event_args)
#define AMDKFD_IOC_RESET_EVENT AMDKFD_IOW(0x0B, struct kfd_ioctl_reset_event_args)
#define AMDKFD_IOC_WAIT_EVENTS AMDKFD_IOWR(0x0C, struct kfd_ioctl_wait_events_args)
#define AMDKFD_IOC_DBG_REGISTER AMDKFD_IOW(0x0D, struct kfd_ioctl_dbg_register_args)
#define AMDKFD_IOC_DBG_UNREGISTER AMDKFD_IOW(0x0E, struct kfd_ioctl_dbg_unregister_args)
#define AMDKFD_IOC_DBG_ADDRESS_WATCH AMDKFD_IOW(0x0F, struct kfd_ioctl_dbg_address_watch_args)
#define AMDKFD_IOC_DBG_WAVE_CONTROL AMDKFD_IOW(0x10, struct kfd_ioctl_dbg_wave_control_args)
#define AMDKFD_IOC_SET_SCRATCH_BACKING_VA AMDKFD_IOWR(0x11, struct kfd_ioctl_set_scratch_backing_va_args)
#define AMDKFD_IOC_GET_TILE_CONFIG AMDKFD_IOWR(0x12, struct kfd_ioctl_get_tile_config_args)
#define AMDKFD_IOC_SET_TRAP_HANDLER AMDKFD_IOW(0x13, struct kfd_ioctl_set_trap_handler_args)
#define AMDKFD_IOC_GET_PROCESS_APERTURES_NEW AMDKFD_IOWR(0x14, struct kfd_ioctl_get_process_apertures_new_args)
#define AMDKFD_IOC_ACQUIRE_VM AMDKFD_IOW(0x15, struct kfd_ioctl_acquire_vm_args)
#define AMDKFD_IOC_ALLOC_MEMORY_OF_GPU AMDKFD_IOWR(0x16, struct kfd_ioctl_alloc_memory_of_gpu_args)
#define AMDKFD_IOC_FREE_MEMORY_OF_GPU AMDKFD_IOW(0x17, struct kfd_ioctl_free_memory_of_gpu_args)
#define AMDKFD_IOC_MAP_MEMORY_TO_GPU AMDKFD_IOWR(0x18, struct kfd_ioctl_map_memory_to_gpu_args)
#define AMDKFD_IOC_UNMAP_MEMORY_FROM_GPU AMDKFD_IOWR(0x19, struct kfd_ioctl_unmap_memory_from_gpu_args)
#define AMDKFD_IOC_SET_CU_MASK AMDKFD_IOW(0x1A, struct kfd_ioctl_set_cu_mask_args)
#define AMDKFD_IOC_GET_QUEUE_WAVE_STATE AMDKFD_IOWR(0x1B, struct kfd_ioctl_get_queue_wave_state_args)
#define AMDKFD_IOC_GET_DMABUF_INFO AMDKFD_IOWR(0x1C, struct kfd_ioctl_get_dmabuf_info_args)
#define AMDKFD_IOC_IMPORT_DMABUF AMDKFD_IOWR(0x1D, struct kfd_ioctl_import_dmabuf_args)
#define AMDKFD_IOC_ALLOC_QUEUE_GWS AMDKFD_IOWR(0x1E, struct kfd_ioctl_alloc_queue_gws_args)
#define AMDKFD_IOC_SMI_EVENTS AMDKFD_IOWR(0x1F, struct kfd_ioctl_smi_events_args)
#define AMDKFD_COMMAND_START 0x01
#define AMDKFD_COMMAND_END 0x20
#endif