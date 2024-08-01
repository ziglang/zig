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
#ifndef __SND_SST_TOKENS_H__
#define __SND_SST_TOKENS_H__
enum SKL_TKNS {
  SKL_TKN_UUID = 1,
  SKL_TKN_U8_NUM_BLOCKS,
  SKL_TKN_U8_BLOCK_TYPE,
  SKL_TKN_U8_IN_PIN_TYPE,
  SKL_TKN_U8_OUT_PIN_TYPE,
  SKL_TKN_U8_DYN_IN_PIN,
  SKL_TKN_U8_DYN_OUT_PIN,
  SKL_TKN_U8_IN_QUEUE_COUNT,
  SKL_TKN_U8_OUT_QUEUE_COUNT,
  SKL_TKN_U8_TIME_SLOT,
  SKL_TKN_U8_CORE_ID,
  SKL_TKN_U8_MOD_TYPE,
  SKL_TKN_U8_CONN_TYPE,
  SKL_TKN_U8_DEV_TYPE,
  SKL_TKN_U8_HW_CONN_TYPE,
  SKL_TKN_U16_MOD_INST_ID,
  SKL_TKN_U16_BLOCK_SIZE,
  SKL_TKN_U32_MAX_MCPS,
  SKL_TKN_U32_MEM_PAGES,
  SKL_TKN_U32_OBS,
  SKL_TKN_U32_IBS,
  SKL_TKN_U32_VBUS_ID,
  SKL_TKN_U32_PARAMS_FIXUP,
  SKL_TKN_U32_CONVERTER,
  SKL_TKN_U32_PIPE_ID,
  SKL_TKN_U32_PIPE_CONN_TYPE,
  SKL_TKN_U32_PIPE_PRIORITY,
  SKL_TKN_U32_PIPE_MEM_PGS,
  SKL_TKN_U32_DIR_PIN_COUNT,
  SKL_TKN_U32_FMT_CH,
  SKL_TKN_U32_FMT_FREQ,
  SKL_TKN_U32_FMT_BIT_DEPTH,
  SKL_TKN_U32_FMT_SAMPLE_SIZE,
  SKL_TKN_U32_FMT_CH_CONFIG,
  SKL_TKN_U32_FMT_INTERLEAVE,
  SKL_TKN_U32_FMT_SAMPLE_TYPE,
  SKL_TKN_U32_FMT_CH_MAP,
  SKL_TKN_U32_PIN_MOD_ID,
  SKL_TKN_U32_PIN_INST_ID,
  SKL_TKN_U32_MOD_SET_PARAMS,
  SKL_TKN_U32_MOD_PARAM_ID,
  SKL_TKN_U32_CAPS_SET_PARAMS,
  SKL_TKN_U32_CAPS_PARAMS_ID,
  SKL_TKN_U32_CAPS_SIZE,
  SKL_TKN_U32_PROC_DOMAIN,
  SKL_TKN_U32_LIB_COUNT,
  SKL_TKN_STR_LIB_NAME,
  SKL_TKN_U32_PMODE,
  SKL_TKL_U32_D0I3_CAPS,
  SKL_TKN_U32_D0I3_CAPS = SKL_TKL_U32_D0I3_CAPS,
  SKL_TKN_U32_DMA_BUF_SIZE,
  SKL_TKN_U32_PIPE_DIRECTION,
  SKL_TKN_U32_PIPE_CONFIG_ID,
  SKL_TKN_U32_NUM_CONFIGS,
  SKL_TKN_U32_PATH_MEM_PGS,
  SKL_TKN_U32_CFG_FREQ,
  SKL_TKN_U8_CFG_CHAN,
  SKL_TKN_U8_CFG_BPS,
  SKL_TKN_CFG_MOD_RES_ID,
  SKL_TKN_CFG_MOD_FMT_ID,
  SKL_TKN_U8_NUM_MOD,
  SKL_TKN_MM_U8_MOD_IDX,
  SKL_TKN_MM_U8_NUM_RES,
  SKL_TKN_MM_U8_NUM_INTF,
  SKL_TKN_MM_U32_RES_ID,
  SKL_TKN_MM_U32_CPS,
  SKL_TKN_MM_U32_DMA_SIZE,
  SKL_TKN_MM_U32_CPC,
  SKL_TKN_MM_U32_RES_PIN_ID,
  SKL_TKN_MM_U32_INTF_PIN_ID,
  SKL_TKN_MM_U32_PIN_BUF,
  SKL_TKN_MM_U32_FMT_ID,
  SKL_TKN_MM_U32_NUM_IN_FMT,
  SKL_TKN_MM_U32_NUM_OUT_FMT,
  SKL_TKN_U32_ASTATE_IDX,
  SKL_TKN_U32_ASTATE_COUNT,
  SKL_TKN_U32_ASTATE_KCPS,
  SKL_TKN_U32_ASTATE_CLK_SRC,
  SKL_TKN_MAX = SKL_TKN_U32_ASTATE_CLK_SRC,
};
#endif