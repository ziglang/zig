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
#ifndef __HDA_TPLG_INTERFACE_H__
#define __HDA_TPLG_INTERFACE_H__
#include <linux/types.h>
#define SKL_CONTROL_TYPE_BYTE_TLV 0x100
#define SKL_CONTROL_TYPE_MIC_SELECT 0x102
#define SKL_CONTROL_TYPE_MULTI_IO_SELECT 0x103
#define SKL_CONTROL_TYPE_MULTI_IO_SELECT_DMIC 0x104
#define HDA_SST_CFG_MAX 900
#define MAX_IN_QUEUE 8
#define MAX_OUT_QUEUE 8
#define SKL_UUID_STR_SZ 40
enum skl_event_types {
  SKL_EVENT_NONE = 0,
  SKL_MIXER_EVENT,
  SKL_MUX_EVENT,
  SKL_VMIXER_EVENT,
  SKL_PGA_EVENT
};
enum skl_ch_cfg {
  SKL_CH_CFG_MONO = 0,
  SKL_CH_CFG_STEREO = 1,
  SKL_CH_CFG_2_1 = 2,
  SKL_CH_CFG_3_0 = 3,
  SKL_CH_CFG_3_1 = 4,
  SKL_CH_CFG_QUATRO = 5,
  SKL_CH_CFG_4_0 = 6,
  SKL_CH_CFG_5_0 = 7,
  SKL_CH_CFG_5_1 = 8,
  SKL_CH_CFG_DUAL_MONO = 9,
  SKL_CH_CFG_I2S_DUAL_STEREO_0 = 10,
  SKL_CH_CFG_I2S_DUAL_STEREO_1 = 11,
  SKL_CH_CFG_4_CHANNEL = 12,
  SKL_CH_CFG_INVALID
};
enum skl_module_type {
  SKL_MODULE_TYPE_MIXER = 0,
  SKL_MODULE_TYPE_COPIER,
  SKL_MODULE_TYPE_UPDWMIX,
  SKL_MODULE_TYPE_SRCINT,
  SKL_MODULE_TYPE_ALGO,
  SKL_MODULE_TYPE_BASE_OUTFMT,
  SKL_MODULE_TYPE_KPB,
  SKL_MODULE_TYPE_MIC_SELECT,
};
enum skl_core_affinity {
  SKL_AFFINITY_CORE_0 = 0,
  SKL_AFFINITY_CORE_1,
  SKL_AFFINITY_CORE_MAX
};
enum skl_pipe_conn_type {
  SKL_PIPE_CONN_TYPE_NONE = 0,
  SKL_PIPE_CONN_TYPE_FE,
  SKL_PIPE_CONN_TYPE_BE
};
enum skl_hw_conn_type {
  SKL_CONN_NONE = 0,
  SKL_CONN_SOURCE = 1,
  SKL_CONN_SINK = 2
};
enum skl_dev_type {
  SKL_DEVICE_BT = 0x0,
  SKL_DEVICE_DMIC = 0x1,
  SKL_DEVICE_I2S = 0x2,
  SKL_DEVICE_SLIMBUS = 0x3,
  SKL_DEVICE_HDALINK = 0x4,
  SKL_DEVICE_HDAHOST = 0x5,
  SKL_DEVICE_NONE
};
enum skl_interleaving {
  SKL_INTERLEAVING_PER_CHANNEL = 0,
  SKL_INTERLEAVING_PER_SAMPLE = 1,
};
enum skl_sample_type {
  SKL_SAMPLE_TYPE_INT_MSB = 0,
  SKL_SAMPLE_TYPE_INT_LSB = 1,
  SKL_SAMPLE_TYPE_INT_SIGNED = 2,
  SKL_SAMPLE_TYPE_INT_UNSIGNED = 3,
  SKL_SAMPLE_TYPE_FLOAT = 4
};
enum module_pin_type {
  SKL_PIN_TYPE_HOMOGENEOUS,
  SKL_PIN_TYPE_HETEROGENEOUS,
};
enum skl_module_param_type {
  SKL_PARAM_DEFAULT = 0,
  SKL_PARAM_INIT,
  SKL_PARAM_SET,
  SKL_PARAM_BIND
};
struct skl_dfw_algo_data {
  __u32 set_params : 2;
  __u32 rsvd : 30;
  __u32 param_id;
  __u32 max;
  char params[0];
} __packed;
enum skl_tkn_dir {
  SKL_DIR_IN,
  SKL_DIR_OUT
};
enum skl_tuple_type {
  SKL_TYPE_TUPLE,
  SKL_TYPE_DATA
};
struct skl_dfw_v4_module_pin {
  __u16 module_id;
  __u16 instance_id;
} __packed;
struct skl_dfw_v4_module_fmt {
  __u32 channels;
  __u32 freq;
  __u32 bit_depth;
  __u32 valid_bit_depth;
  __u32 ch_cfg;
  __u32 interleaving_style;
  __u32 sample_type;
  __u32 ch_map;
} __packed;
struct skl_dfw_v4_module_caps {
  __u32 set_params : 2;
  __u32 rsvd : 30;
  __u32 param_id;
  __u32 caps_size;
  __u32 caps[HDA_SST_CFG_MAX];
} __packed;
struct skl_dfw_v4_pipe {
  __u8 pipe_id;
  __u8 pipe_priority;
  __u16 conn_type : 4;
  __u16 rsvd : 4;
  __u16 memory_pages : 8;
} __packed;
struct skl_dfw_v4_module {
  char uuid[SKL_UUID_STR_SZ];
  __u16 module_id;
  __u16 instance_id;
  __u32 max_mcps;
  __u32 mem_pages;
  __u32 obs;
  __u32 ibs;
  __u32 vbus_id;
  __u32 max_in_queue : 8;
  __u32 max_out_queue : 8;
  __u32 time_slot : 8;
  __u32 core_id : 4;
  __u32 rsvd1 : 4;
  __u32 module_type : 8;
  __u32 conn_type : 4;
  __u32 dev_type : 4;
  __u32 hw_conn_type : 4;
  __u32 rsvd2 : 12;
  __u32 params_fixup : 8;
  __u32 converter : 8;
  __u32 input_pin_type : 1;
  __u32 output_pin_type : 1;
  __u32 is_dynamic_in_pin : 1;
  __u32 is_dynamic_out_pin : 1;
  __u32 is_loadable : 1;
  __u32 rsvd3 : 11;
  struct skl_dfw_v4_pipe pipe;
  struct skl_dfw_v4_module_fmt in_fmt[MAX_IN_QUEUE];
  struct skl_dfw_v4_module_fmt out_fmt[MAX_OUT_QUEUE];
  struct skl_dfw_v4_module_pin in_pin[MAX_IN_QUEUE];
  struct skl_dfw_v4_module_pin out_pin[MAX_OUT_QUEUE];
  struct skl_dfw_v4_module_caps caps;
} __packed;
#endif