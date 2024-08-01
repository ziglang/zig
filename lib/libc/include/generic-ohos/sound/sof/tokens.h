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
#ifndef __INCLUDE_UAPI_SOF_TOPOLOGY_H__
#define __INCLUDE_UAPI_SOF_TOPOLOGY_H__
#define SOF_TPLG_KCTL_VOL_ID 256
#define SOF_TPLG_KCTL_ENUM_ID 257
#define SOF_TPLG_KCTL_BYTES_ID 258
#define SOF_TPLG_KCTL_SWITCH_ID 259
#define SOF_TPLG_KCTL_BYTES_VOLATILE_RO 260
#define SOF_TPLG_KCTL_BYTES_VOLATILE_RW 261
#define SOF_TPLG_KCTL_BYTES_WO_ID 262
#define SOF_TKN_BUF_SIZE 100
#define SOF_TKN_BUF_CAPS 101
#define SOF_TKN_DAI_TYPE 154
#define SOF_TKN_DAI_INDEX 155
#define SOF_TKN_DAI_DIRECTION 156
#define SOF_TKN_SCHED_PERIOD 200
#define SOF_TKN_SCHED_PRIORITY 201
#define SOF_TKN_SCHED_MIPS 202
#define SOF_TKN_SCHED_CORE 203
#define SOF_TKN_SCHED_FRAMES 204
#define SOF_TKN_SCHED_TIME_DOMAIN 205
#define SOF_TKN_VOLUME_RAMP_STEP_TYPE 250
#define SOF_TKN_VOLUME_RAMP_STEP_MS 251
#define SOF_TKN_SRC_RATE_IN 300
#define SOF_TKN_SRC_RATE_OUT 301
#define SOF_TKN_ASRC_RATE_IN 320
#define SOF_TKN_ASRC_RATE_OUT 321
#define SOF_TKN_ASRC_ASYNCHRONOUS_MODE 322
#define SOF_TKN_ASRC_OPERATION_MODE 323
#define SOF_TKN_PCM_DMAC_CONFIG 353
#define SOF_TKN_COMP_PERIOD_SINK_COUNT 400
#define SOF_TKN_COMP_PERIOD_SOURCE_COUNT 401
#define SOF_TKN_COMP_FORMAT 402
#define SOF_TKN_COMP_CORE_ID 404
#define SOF_TKN_COMP_UUID 405
#define SOF_TKN_INTEL_SSP_CLKS_CONTROL 500
#define SOF_TKN_INTEL_SSP_MCLK_ID 501
#define SOF_TKN_INTEL_SSP_SAMPLE_BITS 502
#define SOF_TKN_INTEL_SSP_FRAME_PULSE_WIDTH 503
#define SOF_TKN_INTEL_SSP_QUIRKS 504
#define SOF_TKN_INTEL_SSP_TDM_PADDING_PER_SLOT 505
#define SOF_TKN_INTEL_SSP_BCLK_DELAY 506
#define SOF_TKN_INTEL_DMIC_DRIVER_VERSION 600
#define SOF_TKN_INTEL_DMIC_CLK_MIN 601
#define SOF_TKN_INTEL_DMIC_CLK_MAX 602
#define SOF_TKN_INTEL_DMIC_DUTY_MIN 603
#define SOF_TKN_INTEL_DMIC_DUTY_MAX 604
#define SOF_TKN_INTEL_DMIC_NUM_PDM_ACTIVE 605
#define SOF_TKN_INTEL_DMIC_SAMPLE_RATE 608
#define SOF_TKN_INTEL_DMIC_FIFO_WORD_LENGTH 609
#define SOF_TKN_INTEL_DMIC_UNMUTE_RAMP_TIME_MS 610
#define SOF_TKN_INTEL_DMIC_PDM_CTRL_ID 700
#define SOF_TKN_INTEL_DMIC_PDM_MIC_A_Enable 701
#define SOF_TKN_INTEL_DMIC_PDM_MIC_B_Enable 702
#define SOF_TKN_INTEL_DMIC_PDM_POLARITY_A 703
#define SOF_TKN_INTEL_DMIC_PDM_POLARITY_B 704
#define SOF_TKN_INTEL_DMIC_PDM_CLK_EDGE 705
#define SOF_TKN_INTEL_DMIC_PDM_SKEW 706
#define SOF_TKN_TONE_SAMPLE_RATE 800
#define SOF_TKN_PROCESS_TYPE 900
#define SOF_TKN_EFFECT_TYPE SOF_TKN_PROCESS_TYPE
#define SOF_TKN_IMX_SAI_MCLK_ID 1000
#define SOF_TKN_IMX_ESAI_MCLK_ID 1100
#define SOF_TKN_STREAM_PLAYBACK_COMPATIBLE_D0I3 1200
#define SOF_TKN_STREAM_CAPTURE_COMPATIBLE_D0I3 1201
#define SOF_TKN_MUTE_LED_USE 1300
#define SOF_TKN_MUTE_LED_DIRECTION 1301
#define SOF_TKN_INTEL_ALH_RATE 1400
#define SOF_TKN_INTEL_ALH_CH 1401
#define SOF_TKN_INTEL_HDA_RATE 1500
#define SOF_TKN_INTEL_HDA_CH 1501
#endif