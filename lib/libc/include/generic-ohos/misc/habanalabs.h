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
#ifndef HABANALABS_H_
#define HABANALABS_H_
#include <linux/types.h>
#include <linux/ioctl.h>
#define GOYA_KMD_SRAM_RESERVED_SIZE_FROM_START 0x8000
#define GAUDI_DRIVER_SRAM_RESERVED_SIZE_FROM_START 0x80
#define GAUDI_FIRST_AVAILABLE_W_S_SYNC_OBJECT 48
#define GAUDI_FIRST_AVAILABLE_W_S_MONITOR 24
enum goya_queue_id {
  GOYA_QUEUE_ID_DMA_0 = 0,
  GOYA_QUEUE_ID_DMA_1 = 1,
  GOYA_QUEUE_ID_DMA_2 = 2,
  GOYA_QUEUE_ID_DMA_3 = 3,
  GOYA_QUEUE_ID_DMA_4 = 4,
  GOYA_QUEUE_ID_CPU_PQ = 5,
  GOYA_QUEUE_ID_MME = 6,
  GOYA_QUEUE_ID_TPC0 = 7,
  GOYA_QUEUE_ID_TPC1 = 8,
  GOYA_QUEUE_ID_TPC2 = 9,
  GOYA_QUEUE_ID_TPC3 = 10,
  GOYA_QUEUE_ID_TPC4 = 11,
  GOYA_QUEUE_ID_TPC5 = 12,
  GOYA_QUEUE_ID_TPC6 = 13,
  GOYA_QUEUE_ID_TPC7 = 14,
  GOYA_QUEUE_ID_SIZE
};
enum gaudi_queue_id {
  GAUDI_QUEUE_ID_DMA_0_0 = 0,
  GAUDI_QUEUE_ID_DMA_0_1 = 1,
  GAUDI_QUEUE_ID_DMA_0_2 = 2,
  GAUDI_QUEUE_ID_DMA_0_3 = 3,
  GAUDI_QUEUE_ID_DMA_1_0 = 4,
  GAUDI_QUEUE_ID_DMA_1_1 = 5,
  GAUDI_QUEUE_ID_DMA_1_2 = 6,
  GAUDI_QUEUE_ID_DMA_1_3 = 7,
  GAUDI_QUEUE_ID_CPU_PQ = 8,
  GAUDI_QUEUE_ID_DMA_2_0 = 9,
  GAUDI_QUEUE_ID_DMA_2_1 = 10,
  GAUDI_QUEUE_ID_DMA_2_2 = 11,
  GAUDI_QUEUE_ID_DMA_2_3 = 12,
  GAUDI_QUEUE_ID_DMA_3_0 = 13,
  GAUDI_QUEUE_ID_DMA_3_1 = 14,
  GAUDI_QUEUE_ID_DMA_3_2 = 15,
  GAUDI_QUEUE_ID_DMA_3_3 = 16,
  GAUDI_QUEUE_ID_DMA_4_0 = 17,
  GAUDI_QUEUE_ID_DMA_4_1 = 18,
  GAUDI_QUEUE_ID_DMA_4_2 = 19,
  GAUDI_QUEUE_ID_DMA_4_3 = 20,
  GAUDI_QUEUE_ID_DMA_5_0 = 21,
  GAUDI_QUEUE_ID_DMA_5_1 = 22,
  GAUDI_QUEUE_ID_DMA_5_2 = 23,
  GAUDI_QUEUE_ID_DMA_5_3 = 24,
  GAUDI_QUEUE_ID_DMA_6_0 = 25,
  GAUDI_QUEUE_ID_DMA_6_1 = 26,
  GAUDI_QUEUE_ID_DMA_6_2 = 27,
  GAUDI_QUEUE_ID_DMA_6_3 = 28,
  GAUDI_QUEUE_ID_DMA_7_0 = 29,
  GAUDI_QUEUE_ID_DMA_7_1 = 30,
  GAUDI_QUEUE_ID_DMA_7_2 = 31,
  GAUDI_QUEUE_ID_DMA_7_3 = 32,
  GAUDI_QUEUE_ID_MME_0_0 = 33,
  GAUDI_QUEUE_ID_MME_0_1 = 34,
  GAUDI_QUEUE_ID_MME_0_2 = 35,
  GAUDI_QUEUE_ID_MME_0_3 = 36,
  GAUDI_QUEUE_ID_MME_1_0 = 37,
  GAUDI_QUEUE_ID_MME_1_1 = 38,
  GAUDI_QUEUE_ID_MME_1_2 = 39,
  GAUDI_QUEUE_ID_MME_1_3 = 40,
  GAUDI_QUEUE_ID_TPC_0_0 = 41,
  GAUDI_QUEUE_ID_TPC_0_1 = 42,
  GAUDI_QUEUE_ID_TPC_0_2 = 43,
  GAUDI_QUEUE_ID_TPC_0_3 = 44,
  GAUDI_QUEUE_ID_TPC_1_0 = 45,
  GAUDI_QUEUE_ID_TPC_1_1 = 46,
  GAUDI_QUEUE_ID_TPC_1_2 = 47,
  GAUDI_QUEUE_ID_TPC_1_3 = 48,
  GAUDI_QUEUE_ID_TPC_2_0 = 49,
  GAUDI_QUEUE_ID_TPC_2_1 = 50,
  GAUDI_QUEUE_ID_TPC_2_2 = 51,
  GAUDI_QUEUE_ID_TPC_2_3 = 52,
  GAUDI_QUEUE_ID_TPC_3_0 = 53,
  GAUDI_QUEUE_ID_TPC_3_1 = 54,
  GAUDI_QUEUE_ID_TPC_3_2 = 55,
  GAUDI_QUEUE_ID_TPC_3_3 = 56,
  GAUDI_QUEUE_ID_TPC_4_0 = 57,
  GAUDI_QUEUE_ID_TPC_4_1 = 58,
  GAUDI_QUEUE_ID_TPC_4_2 = 59,
  GAUDI_QUEUE_ID_TPC_4_3 = 60,
  GAUDI_QUEUE_ID_TPC_5_0 = 61,
  GAUDI_QUEUE_ID_TPC_5_1 = 62,
  GAUDI_QUEUE_ID_TPC_5_2 = 63,
  GAUDI_QUEUE_ID_TPC_5_3 = 64,
  GAUDI_QUEUE_ID_TPC_6_0 = 65,
  GAUDI_QUEUE_ID_TPC_6_1 = 66,
  GAUDI_QUEUE_ID_TPC_6_2 = 67,
  GAUDI_QUEUE_ID_TPC_6_3 = 68,
  GAUDI_QUEUE_ID_TPC_7_0 = 69,
  GAUDI_QUEUE_ID_TPC_7_1 = 70,
  GAUDI_QUEUE_ID_TPC_7_2 = 71,
  GAUDI_QUEUE_ID_TPC_7_3 = 72,
  GAUDI_QUEUE_ID_NIC_0_0 = 73,
  GAUDI_QUEUE_ID_NIC_0_1 = 74,
  GAUDI_QUEUE_ID_NIC_0_2 = 75,
  GAUDI_QUEUE_ID_NIC_0_3 = 76,
  GAUDI_QUEUE_ID_NIC_1_0 = 77,
  GAUDI_QUEUE_ID_NIC_1_1 = 78,
  GAUDI_QUEUE_ID_NIC_1_2 = 79,
  GAUDI_QUEUE_ID_NIC_1_3 = 80,
  GAUDI_QUEUE_ID_NIC_2_0 = 81,
  GAUDI_QUEUE_ID_NIC_2_1 = 82,
  GAUDI_QUEUE_ID_NIC_2_2 = 83,
  GAUDI_QUEUE_ID_NIC_2_3 = 84,
  GAUDI_QUEUE_ID_NIC_3_0 = 85,
  GAUDI_QUEUE_ID_NIC_3_1 = 86,
  GAUDI_QUEUE_ID_NIC_3_2 = 87,
  GAUDI_QUEUE_ID_NIC_3_3 = 88,
  GAUDI_QUEUE_ID_NIC_4_0 = 89,
  GAUDI_QUEUE_ID_NIC_4_1 = 90,
  GAUDI_QUEUE_ID_NIC_4_2 = 91,
  GAUDI_QUEUE_ID_NIC_4_3 = 92,
  GAUDI_QUEUE_ID_NIC_5_0 = 93,
  GAUDI_QUEUE_ID_NIC_5_1 = 94,
  GAUDI_QUEUE_ID_NIC_5_2 = 95,
  GAUDI_QUEUE_ID_NIC_5_3 = 96,
  GAUDI_QUEUE_ID_NIC_6_0 = 97,
  GAUDI_QUEUE_ID_NIC_6_1 = 98,
  GAUDI_QUEUE_ID_NIC_6_2 = 99,
  GAUDI_QUEUE_ID_NIC_6_3 = 100,
  GAUDI_QUEUE_ID_NIC_7_0 = 101,
  GAUDI_QUEUE_ID_NIC_7_1 = 102,
  GAUDI_QUEUE_ID_NIC_7_2 = 103,
  GAUDI_QUEUE_ID_NIC_7_3 = 104,
  GAUDI_QUEUE_ID_NIC_8_0 = 105,
  GAUDI_QUEUE_ID_NIC_8_1 = 106,
  GAUDI_QUEUE_ID_NIC_8_2 = 107,
  GAUDI_QUEUE_ID_NIC_8_3 = 108,
  GAUDI_QUEUE_ID_NIC_9_0 = 109,
  GAUDI_QUEUE_ID_NIC_9_1 = 110,
  GAUDI_QUEUE_ID_NIC_9_2 = 111,
  GAUDI_QUEUE_ID_NIC_9_3 = 112,
  GAUDI_QUEUE_ID_SIZE
};
enum goya_engine_id {
  GOYA_ENGINE_ID_DMA_0 = 0,
  GOYA_ENGINE_ID_DMA_1,
  GOYA_ENGINE_ID_DMA_2,
  GOYA_ENGINE_ID_DMA_3,
  GOYA_ENGINE_ID_DMA_4,
  GOYA_ENGINE_ID_MME_0,
  GOYA_ENGINE_ID_TPC_0,
  GOYA_ENGINE_ID_TPC_1,
  GOYA_ENGINE_ID_TPC_2,
  GOYA_ENGINE_ID_TPC_3,
  GOYA_ENGINE_ID_TPC_4,
  GOYA_ENGINE_ID_TPC_5,
  GOYA_ENGINE_ID_TPC_6,
  GOYA_ENGINE_ID_TPC_7,
  GOYA_ENGINE_ID_SIZE
};
enum gaudi_engine_id {
  GAUDI_ENGINE_ID_DMA_0 = 0,
  GAUDI_ENGINE_ID_DMA_1,
  GAUDI_ENGINE_ID_DMA_2,
  GAUDI_ENGINE_ID_DMA_3,
  GAUDI_ENGINE_ID_DMA_4,
  GAUDI_ENGINE_ID_DMA_5,
  GAUDI_ENGINE_ID_DMA_6,
  GAUDI_ENGINE_ID_DMA_7,
  GAUDI_ENGINE_ID_MME_0,
  GAUDI_ENGINE_ID_MME_1,
  GAUDI_ENGINE_ID_MME_2,
  GAUDI_ENGINE_ID_MME_3,
  GAUDI_ENGINE_ID_TPC_0,
  GAUDI_ENGINE_ID_TPC_1,
  GAUDI_ENGINE_ID_TPC_2,
  GAUDI_ENGINE_ID_TPC_3,
  GAUDI_ENGINE_ID_TPC_4,
  GAUDI_ENGINE_ID_TPC_5,
  GAUDI_ENGINE_ID_TPC_6,
  GAUDI_ENGINE_ID_TPC_7,
  GAUDI_ENGINE_ID_NIC_0,
  GAUDI_ENGINE_ID_NIC_1,
  GAUDI_ENGINE_ID_NIC_2,
  GAUDI_ENGINE_ID_NIC_3,
  GAUDI_ENGINE_ID_NIC_4,
  GAUDI_ENGINE_ID_NIC_5,
  GAUDI_ENGINE_ID_NIC_6,
  GAUDI_ENGINE_ID_NIC_7,
  GAUDI_ENGINE_ID_NIC_8,
  GAUDI_ENGINE_ID_NIC_9,
  GAUDI_ENGINE_ID_SIZE
};
enum hl_device_status {
  HL_DEVICE_STATUS_OPERATIONAL,
  HL_DEVICE_STATUS_IN_RESET,
  HL_DEVICE_STATUS_MALFUNCTION
};
#define HL_INFO_HW_IP_INFO 0
#define HL_INFO_HW_EVENTS 1
#define HL_INFO_DRAM_USAGE 2
#define HL_INFO_HW_IDLE 3
#define HL_INFO_DEVICE_STATUS 4
#define HL_INFO_DEVICE_UTILIZATION 6
#define HL_INFO_HW_EVENTS_AGGREGATE 7
#define HL_INFO_CLK_RATE 8
#define HL_INFO_RESET_COUNT 9
#define HL_INFO_TIME_SYNC 10
#define HL_INFO_CS_COUNTERS 11
#define HL_INFO_PCI_COUNTERS 12
#define HL_INFO_CLK_THROTTLE_REASON 13
#define HL_INFO_SYNC_MANAGER 14
#define HL_INFO_TOTAL_ENERGY 15
#define HL_INFO_VERSION_MAX_LEN 128
#define HL_INFO_CARD_NAME_MAX_LEN 16
struct hl_info_hw_ip_info {
  __u64 sram_base_address;
  __u64 dram_base_address;
  __u64 dram_size;
  __u32 sram_size;
  __u32 num_of_events;
  __u32 device_id;
  __u32 module_id;
  __u32 reserved[2];
  __u32 cpld_version;
  __u32 psoc_pci_pll_nr;
  __u32 psoc_pci_pll_nf;
  __u32 psoc_pci_pll_od;
  __u32 psoc_pci_pll_div_factor;
  __u8 tpc_enabled_mask;
  __u8 dram_enabled;
  __u8 pad[2];
  __u8 cpucp_version[HL_INFO_VERSION_MAX_LEN];
  __u8 card_name[HL_INFO_CARD_NAME_MAX_LEN];
};
struct hl_info_dram_usage {
  __u64 dram_free_mem;
  __u64 ctx_dram_mem;
};
struct hl_info_hw_idle {
  __u32 is_idle;
  __u32 busy_engines_mask;
  __u64 busy_engines_mask_ext;
};
struct hl_info_device_status {
  __u32 status;
  __u32 pad;
};
struct hl_info_device_utilization {
  __u32 utilization;
  __u32 pad;
};
struct hl_info_clk_rate {
  __u32 cur_clk_rate_mhz;
  __u32 max_clk_rate_mhz;
};
struct hl_info_reset_count {
  __u32 hard_reset_cnt;
  __u32 soft_reset_cnt;
};
struct hl_info_time_sync {
  __u64 device_time;
  __u64 host_time;
};
struct hl_info_pci_counters {
  __u64 rx_throughput;
  __u64 tx_throughput;
  __u64 replay_cnt;
};
#define HL_CLK_THROTTLE_POWER 0x1
#define HL_CLK_THROTTLE_THERMAL 0x2
struct hl_info_clk_throttle {
  __u32 clk_throttling_reason;
};
struct hl_info_energy {
  __u64 total_energy_consumption;
};
struct hl_info_sync_manager {
  __u32 first_available_sync_object;
  __u32 first_available_monitor;
};
struct hl_cs_counters {
  __u64 out_of_mem_drop_cnt;
  __u64 parsing_drop_cnt;
  __u64 queue_full_drop_cnt;
  __u64 device_in_reset_drop_cnt;
  __u64 max_cs_in_flight_drop_cnt;
};
struct hl_info_cs_counters {
  struct hl_cs_counters cs_counters;
  struct hl_cs_counters ctx_cs_counters;
};
enum gaudi_dcores {
  HL_GAUDI_WS_DCORE,
  HL_GAUDI_WN_DCORE,
  HL_GAUDI_EN_DCORE,
  HL_GAUDI_ES_DCORE
};
struct hl_info_args {
  __u64 return_pointer;
  __u32 return_size;
  __u32 op;
  union {
    __u32 dcore_id;
    __u32 ctx_id;
    __u32 period_ms;
  };
  __u32 pad;
};
#define HL_CB_OP_CREATE 0
#define HL_CB_OP_DESTROY 1
#define HL_MAX_CB_SIZE (0x200000 - 32)
#define HL_CB_FLAGS_MAP 0x1
struct hl_cb_in {
  __u64 cb_handle;
  __u32 op;
  __u32 cb_size;
  __u32 ctx_id;
  __u32 flags;
};
struct hl_cb_out {
  __u64 cb_handle;
};
union hl_cb_args {
  struct hl_cb_in in;
  struct hl_cb_out out;
};
struct hl_cs_chunk {
  union {
    __u64 cb_handle;
    __u64 signal_seq_arr;
  };
  __u32 queue_index;
  union {
    __u32 cb_size;
    __u32 num_signal_seq_arr;
  };
  __u32 cs_chunk_flags;
  __u32 pad[11];
};
#define HL_CS_FLAGS_FORCE_RESTORE 0x1
#define HL_CS_FLAGS_SIGNAL 0x2
#define HL_CS_FLAGS_WAIT 0x4
#define HL_CS_STATUS_SUCCESS 0
#define HL_MAX_JOBS_PER_CS 512
struct hl_cs_in {
  __u64 chunks_restore;
  __u64 chunks_execute;
  __u64 chunks_store;
  __u32 num_chunks_restore;
  __u32 num_chunks_execute;
  __u32 num_chunks_store;
  __u32 cs_flags;
  __u32 ctx_id;
};
struct hl_cs_out {
  __u64 seq;
  __u32 status;
  __u32 pad;
};
union hl_cs_args {
  struct hl_cs_in in;
  struct hl_cs_out out;
};
struct hl_wait_cs_in {
  __u64 seq;
  __u64 timeout_us;
  __u32 ctx_id;
  __u32 pad;
};
#define HL_WAIT_CS_STATUS_COMPLETED 0
#define HL_WAIT_CS_STATUS_BUSY 1
#define HL_WAIT_CS_STATUS_TIMEDOUT 2
#define HL_WAIT_CS_STATUS_ABORTED 3
#define HL_WAIT_CS_STATUS_INTERRUPTED 4
struct hl_wait_cs_out {
  __u32 status;
  __u32 pad;
};
union hl_wait_cs_args {
  struct hl_wait_cs_in in;
  struct hl_wait_cs_out out;
};
#define HL_MEM_OP_ALLOC 0
#define HL_MEM_OP_FREE 1
#define HL_MEM_OP_MAP 2
#define HL_MEM_OP_UNMAP 3
#define HL_MEM_CONTIGUOUS 0x1
#define HL_MEM_SHARED 0x2
#define HL_MEM_USERPTR 0x4
struct hl_mem_in {
  union {
    struct {
      __u64 mem_size;
    } alloc;
    struct {
      __u64 handle;
    } free;
    struct {
      __u64 hint_addr;
      __u64 handle;
    } map_device;
    struct {
      __u64 host_virt_addr;
      __u64 hint_addr;
      __u64 mem_size;
    } map_host;
    struct {
      __u64 device_virt_addr;
    } unmap;
  };
  __u32 op;
  __u32 flags;
  __u32 ctx_id;
  __u32 pad;
};
struct hl_mem_out {
  union {
    __u64 device_virt_addr;
    __u64 handle;
  };
};
union hl_mem_args {
  struct hl_mem_in in;
  struct hl_mem_out out;
};
#define HL_DEBUG_MAX_AUX_VALUES 10
struct hl_debug_params_etr {
  __u64 buffer_address;
  __u64 buffer_size;
  __u32 sink_mode;
  __u32 pad;
};
struct hl_debug_params_etf {
  __u64 buffer_address;
  __u64 buffer_size;
  __u32 sink_mode;
  __u32 pad;
};
struct hl_debug_params_stm {
  __u64 he_mask;
  __u64 sp_mask;
  __u32 id;
  __u32 frequency;
};
struct hl_debug_params_bmon {
  __u64 start_addr0;
  __u64 addr_mask0;
  __u64 start_addr1;
  __u64 addr_mask1;
  __u32 bw_win;
  __u32 win_capture;
  __u32 id;
  __u32 pad;
};
struct hl_debug_params_spmu {
  __u64 event_types[HL_DEBUG_MAX_AUX_VALUES];
  __u32 event_types_num;
  __u32 pad;
};
#define HL_DEBUG_OP_ETR 0
#define HL_DEBUG_OP_ETF 1
#define HL_DEBUG_OP_STM 2
#define HL_DEBUG_OP_FUNNEL 3
#define HL_DEBUG_OP_BMON 4
#define HL_DEBUG_OP_SPMU 5
#define HL_DEBUG_OP_TIMESTAMP 6
#define HL_DEBUG_OP_SET_MODE 7
struct hl_debug_args {
  __u64 input_ptr;
  __u64 output_ptr;
  __u32 input_size;
  __u32 output_size;
  __u32 op;
  __u32 reg_idx;
  __u32 enable;
  __u32 ctx_id;
};
#define HL_IOCTL_INFO _IOWR('H', 0x01, struct hl_info_args)
#define HL_IOCTL_CB _IOWR('H', 0x02, union hl_cb_args)
#define HL_IOCTL_CS _IOWR('H', 0x03, union hl_cs_args)
#define HL_IOCTL_WAIT_CS _IOWR('H', 0x04, union hl_wait_cs_args)
#define HL_IOCTL_MEMORY _IOWR('H', 0x05, union hl_mem_args)
#define HL_IOCTL_DEBUG _IOWR('H', 0x06, struct hl_debug_args)
#define HL_COMMAND_START 0x01
#define HL_COMMAND_END 0x07
#endif