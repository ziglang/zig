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
#ifndef __XILINX_SDFEC_H__
#define __XILINX_SDFEC_H__
#include <linux/types.h>
#define XSDFEC_LDPC_SC_TABLE_ADDR_BASE (0x10000)
#define XSDFEC_LDPC_SC_TABLE_ADDR_HIGH (0x10400)
#define XSDFEC_LDPC_LA_TABLE_ADDR_BASE (0x18000)
#define XSDFEC_LDPC_LA_TABLE_ADDR_HIGH (0x19000)
#define XSDFEC_LDPC_QC_TABLE_ADDR_BASE (0x20000)
#define XSDFEC_LDPC_QC_TABLE_ADDR_HIGH (0x28000)
#define XSDFEC_SC_TABLE_DEPTH (XSDFEC_LDPC_SC_TABLE_ADDR_HIGH - XSDFEC_LDPC_SC_TABLE_ADDR_BASE)
#define XSDFEC_LA_TABLE_DEPTH (XSDFEC_LDPC_LA_TABLE_ADDR_HIGH - XSDFEC_LDPC_LA_TABLE_ADDR_BASE)
#define XSDFEC_QC_TABLE_DEPTH (XSDFEC_LDPC_QC_TABLE_ADDR_HIGH - XSDFEC_LDPC_QC_TABLE_ADDR_BASE)
enum xsdfec_code {
  XSDFEC_TURBO_CODE = 0,
  XSDFEC_LDPC_CODE,
};
enum xsdfec_order {
  XSDFEC_MAINTAIN_ORDER = 0,
  XSDFEC_OUT_OF_ORDER,
};
enum xsdfec_turbo_alg {
  XSDFEC_MAX_SCALE = 0,
  XSDFEC_MAX_STAR,
  XSDFEC_TURBO_ALG_MAX,
};
enum xsdfec_state {
  XSDFEC_INIT = 0,
  XSDFEC_STARTED,
  XSDFEC_STOPPED,
  XSDFEC_NEEDS_RESET,
  XSDFEC_PL_RECONFIGURE,
};
enum xsdfec_axis_width {
  XSDFEC_1x128b = 1,
  XSDFEC_2x128b = 2,
  XSDFEC_4x128b = 4,
};
enum xsdfec_axis_word_include {
  XSDFEC_FIXED_VALUE = 0,
  XSDFEC_IN_BLOCK,
  XSDFEC_PER_AXI_TRANSACTION,
  XSDFEC_AXIS_WORDS_INCLUDE_MAX,
};
struct xsdfec_turbo {
  __u32 alg;
  __u8 scale;
};
struct xsdfec_ldpc_params {
  __u32 n;
  __u32 k;
  __u32 psize;
  __u32 nlayers;
  __u32 nqc;
  __u32 nmqc;
  __u32 nm;
  __u32 norm_type;
  __u32 no_packing;
  __u32 special_qc;
  __u32 no_final_parity;
  __u32 max_schedule;
  __u32 sc_off;
  __u32 la_off;
  __u32 qc_off;
  __u32 * sc_table;
  __u32 * la_table;
  __u32 * qc_table;
  __u16 code_id;
};
struct xsdfec_status {
  __u32 state;
  __s8 activity;
};
struct xsdfec_irq {
  __s8 enable_isr;
  __s8 enable_ecc_isr;
};
struct xsdfec_config {
  __u32 code;
  __u32 order;
  __u32 din_width;
  __u32 din_word_include;
  __u32 dout_width;
  __u32 dout_word_include;
  struct xsdfec_irq irq;
  __s8 bypass;
  __s8 code_wr_protect;
};
struct xsdfec_stats {
  __u32 isr_err_count;
  __u32 cecc_count;
  __u32 uecc_count;
};
struct xsdfec_ldpc_param_table_sizes {
  __u32 sc_size;
  __u32 la_size;
  __u32 qc_size;
};
#define XSDFEC_MAGIC 'f'
#define XSDFEC_START_DEV _IO(XSDFEC_MAGIC, 0)
#define XSDFEC_STOP_DEV _IO(XSDFEC_MAGIC, 1)
#define XSDFEC_GET_STATUS _IOR(XSDFEC_MAGIC, 2, struct xsdfec_status)
#define XSDFEC_SET_IRQ _IOW(XSDFEC_MAGIC, 3, struct xsdfec_irq)
#define XSDFEC_SET_TURBO _IOW(XSDFEC_MAGIC, 4, struct xsdfec_turbo)
#define XSDFEC_ADD_LDPC_CODE_PARAMS _IOW(XSDFEC_MAGIC, 5, struct xsdfec_ldpc_params)
#define XSDFEC_GET_CONFIG _IOR(XSDFEC_MAGIC, 6, struct xsdfec_config)
#define XSDFEC_GET_TURBO _IOR(XSDFEC_MAGIC, 7, struct xsdfec_turbo)
#define XSDFEC_SET_ORDER _IOW(XSDFEC_MAGIC, 8, unsigned long)
#define XSDFEC_SET_BYPASS _IOW(XSDFEC_MAGIC, 9, bool)
#define XSDFEC_IS_ACTIVE _IOR(XSDFEC_MAGIC, 10, bool)
#define XSDFEC_CLEAR_STATS _IO(XSDFEC_MAGIC, 11)
#define XSDFEC_GET_STATS _IOR(XSDFEC_MAGIC, 12, struct xsdfec_stats)
#define XSDFEC_SET_DEFAULT_CONFIG _IO(XSDFEC_MAGIC, 13)
#endif