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
#ifndef DRM_FOURCC_H
#define DRM_FOURCC_H
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define fourcc_code(a,b,c,d) ((__u32) (a) | ((__u32) (b) << 8) | ((__u32) (c) << 16) | ((__u32) (d) << 24))
#define DRM_FORMAT_BIG_ENDIAN (1U << 31)
#define DRM_FORMAT_INVALID 0
#define DRM_FORMAT_C8 fourcc_code('C', '8', ' ', ' ')
#define DRM_FORMAT_R8 fourcc_code('R', '8', ' ', ' ')
#define DRM_FORMAT_R16 fourcc_code('R', '1', '6', ' ')
#define DRM_FORMAT_RG88 fourcc_code('R', 'G', '8', '8')
#define DRM_FORMAT_GR88 fourcc_code('G', 'R', '8', '8')
#define DRM_FORMAT_RG1616 fourcc_code('R', 'G', '3', '2')
#define DRM_FORMAT_GR1616 fourcc_code('G', 'R', '3', '2')
#define DRM_FORMAT_RGB332 fourcc_code('R', 'G', 'B', '8')
#define DRM_FORMAT_BGR233 fourcc_code('B', 'G', 'R', '8')
#define DRM_FORMAT_XRGB4444 fourcc_code('X', 'R', '1', '2')
#define DRM_FORMAT_XBGR4444 fourcc_code('X', 'B', '1', '2')
#define DRM_FORMAT_RGBX4444 fourcc_code('R', 'X', '1', '2')
#define DRM_FORMAT_BGRX4444 fourcc_code('B', 'X', '1', '2')
#define DRM_FORMAT_ARGB4444 fourcc_code('A', 'R', '1', '2')
#define DRM_FORMAT_ABGR4444 fourcc_code('A', 'B', '1', '2')
#define DRM_FORMAT_RGBA4444 fourcc_code('R', 'A', '1', '2')
#define DRM_FORMAT_BGRA4444 fourcc_code('B', 'A', '1', '2')
#define DRM_FORMAT_XRGB1555 fourcc_code('X', 'R', '1', '5')
#define DRM_FORMAT_XBGR1555 fourcc_code('X', 'B', '1', '5')
#define DRM_FORMAT_RGBX5551 fourcc_code('R', 'X', '1', '5')
#define DRM_FORMAT_BGRX5551 fourcc_code('B', 'X', '1', '5')
#define DRM_FORMAT_ARGB1555 fourcc_code('A', 'R', '1', '5')
#define DRM_FORMAT_ABGR1555 fourcc_code('A', 'B', '1', '5')
#define DRM_FORMAT_RGBA5551 fourcc_code('R', 'A', '1', '5')
#define DRM_FORMAT_BGRA5551 fourcc_code('B', 'A', '1', '5')
#define DRM_FORMAT_RGB565 fourcc_code('R', 'G', '1', '6')
#define DRM_FORMAT_BGR565 fourcc_code('B', 'G', '1', '6')
#define DRM_FORMAT_RGB888 fourcc_code('R', 'G', '2', '4')
#define DRM_FORMAT_BGR888 fourcc_code('B', 'G', '2', '4')
#define DRM_FORMAT_XRGB8888 fourcc_code('X', 'R', '2', '4')
#define DRM_FORMAT_XBGR8888 fourcc_code('X', 'B', '2', '4')
#define DRM_FORMAT_RGBX8888 fourcc_code('R', 'X', '2', '4')
#define DRM_FORMAT_BGRX8888 fourcc_code('B', 'X', '2', '4')
#define DRM_FORMAT_ARGB8888 fourcc_code('A', 'R', '2', '4')
#define DRM_FORMAT_ABGR8888 fourcc_code('A', 'B', '2', '4')
#define DRM_FORMAT_RGBA8888 fourcc_code('R', 'A', '2', '4')
#define DRM_FORMAT_BGRA8888 fourcc_code('B', 'A', '2', '4')
#define DRM_FORMAT_XRGB2101010 fourcc_code('X', 'R', '3', '0')
#define DRM_FORMAT_XBGR2101010 fourcc_code('X', 'B', '3', '0')
#define DRM_FORMAT_RGBX1010102 fourcc_code('R', 'X', '3', '0')
#define DRM_FORMAT_BGRX1010102 fourcc_code('B', 'X', '3', '0')
#define DRM_FORMAT_ARGB2101010 fourcc_code('A', 'R', '3', '0')
#define DRM_FORMAT_ABGR2101010 fourcc_code('A', 'B', '3', '0')
#define DRM_FORMAT_RGBA1010102 fourcc_code('R', 'A', '3', '0')
#define DRM_FORMAT_BGRA1010102 fourcc_code('B', 'A', '3', '0')
#define DRM_FORMAT_XRGB16161616F fourcc_code('X', 'R', '4', 'H')
#define DRM_FORMAT_XBGR16161616F fourcc_code('X', 'B', '4', 'H')
#define DRM_FORMAT_ARGB16161616F fourcc_code('A', 'R', '4', 'H')
#define DRM_FORMAT_ABGR16161616F fourcc_code('A', 'B', '4', 'H')
#define DRM_FORMAT_YUYV fourcc_code('Y', 'U', 'Y', 'V')
#define DRM_FORMAT_YVYU fourcc_code('Y', 'V', 'Y', 'U')
#define DRM_FORMAT_UYVY fourcc_code('U', 'Y', 'V', 'Y')
#define DRM_FORMAT_VYUY fourcc_code('V', 'Y', 'U', 'Y')
#define DRM_FORMAT_AYUV fourcc_code('A', 'Y', 'U', 'V')
#define DRM_FORMAT_XYUV8888 fourcc_code('X', 'Y', 'U', 'V')
#define DRM_FORMAT_VUY888 fourcc_code('V', 'U', '2', '4')
#define DRM_FORMAT_VUY101010 fourcc_code('V', 'U', '3', '0')
#define DRM_FORMAT_Y210 fourcc_code('Y', '2', '1', '0')
#define DRM_FORMAT_Y212 fourcc_code('Y', '2', '1', '2')
#define DRM_FORMAT_Y216 fourcc_code('Y', '2', '1', '6')
#define DRM_FORMAT_Y410 fourcc_code('Y', '4', '1', '0')
#define DRM_FORMAT_Y412 fourcc_code('Y', '4', '1', '2')
#define DRM_FORMAT_Y416 fourcc_code('Y', '4', '1', '6')
#define DRM_FORMAT_XVYU2101010 fourcc_code('X', 'V', '3', '0')
#define DRM_FORMAT_XVYU12_16161616 fourcc_code('X', 'V', '3', '6')
#define DRM_FORMAT_XVYU16161616 fourcc_code('X', 'V', '4', '8')
#define DRM_FORMAT_Y0L0 fourcc_code('Y', '0', 'L', '0')
#define DRM_FORMAT_X0L0 fourcc_code('X', '0', 'L', '0')
#define DRM_FORMAT_Y0L2 fourcc_code('Y', '0', 'L', '2')
#define DRM_FORMAT_X0L2 fourcc_code('X', '0', 'L', '2')
#define DRM_FORMAT_YUV420_8BIT fourcc_code('Y', 'U', '0', '8')
#define DRM_FORMAT_YUV420_10BIT fourcc_code('Y', 'U', '1', '0')
#define DRM_FORMAT_XRGB8888_A8 fourcc_code('X', 'R', 'A', '8')
#define DRM_FORMAT_XBGR8888_A8 fourcc_code('X', 'B', 'A', '8')
#define DRM_FORMAT_RGBX8888_A8 fourcc_code('R', 'X', 'A', '8')
#define DRM_FORMAT_BGRX8888_A8 fourcc_code('B', 'X', 'A', '8')
#define DRM_FORMAT_RGB888_A8 fourcc_code('R', '8', 'A', '8')
#define DRM_FORMAT_BGR888_A8 fourcc_code('B', '8', 'A', '8')
#define DRM_FORMAT_RGB565_A8 fourcc_code('R', '5', 'A', '8')
#define DRM_FORMAT_BGR565_A8 fourcc_code('B', '5', 'A', '8')
#define DRM_FORMAT_NV12 fourcc_code('N', 'V', '1', '2')
#define DRM_FORMAT_NV21 fourcc_code('N', 'V', '2', '1')
#define DRM_FORMAT_NV16 fourcc_code('N', 'V', '1', '6')
#define DRM_FORMAT_NV61 fourcc_code('N', 'V', '6', '1')
#define DRM_FORMAT_NV24 fourcc_code('N', 'V', '2', '4')
#define DRM_FORMAT_NV42 fourcc_code('N', 'V', '4', '2')
#define DRM_FORMAT_NV15 fourcc_code('N', 'V', '1', '5')
#define DRM_FORMAT_P210 fourcc_code('P', '2', '1', '0')
#define DRM_FORMAT_P010 fourcc_code('P', '0', '1', '0')
#define DRM_FORMAT_P012 fourcc_code('P', '0', '1', '2')
#define DRM_FORMAT_P016 fourcc_code('P', '0', '1', '6')
#define DRM_FORMAT_Q410 fourcc_code('Q', '4', '1', '0')
#define DRM_FORMAT_Q401 fourcc_code('Q', '4', '0', '1')
#define DRM_FORMAT_YUV410 fourcc_code('Y', 'U', 'V', '9')
#define DRM_FORMAT_YVU410 fourcc_code('Y', 'V', 'U', '9')
#define DRM_FORMAT_YUV411 fourcc_code('Y', 'U', '1', '1')
#define DRM_FORMAT_YVU411 fourcc_code('Y', 'V', '1', '1')
#define DRM_FORMAT_YUV420 fourcc_code('Y', 'U', '1', '2')
#define DRM_FORMAT_YVU420 fourcc_code('Y', 'V', '1', '2')
#define DRM_FORMAT_YUV422 fourcc_code('Y', 'U', '1', '6')
#define DRM_FORMAT_YVU422 fourcc_code('Y', 'V', '1', '6')
#define DRM_FORMAT_YUV444 fourcc_code('Y', 'U', '2', '4')
#define DRM_FORMAT_YVU444 fourcc_code('Y', 'V', '2', '4')
#define DRM_FORMAT_MOD_NONE 0
#define DRM_FORMAT_MOD_VENDOR_NONE 0
#define DRM_FORMAT_MOD_VENDOR_INTEL 0x01
#define DRM_FORMAT_MOD_VENDOR_AMD 0x02
#define DRM_FORMAT_MOD_VENDOR_NVIDIA 0x03
#define DRM_FORMAT_MOD_VENDOR_SAMSUNG 0x04
#define DRM_FORMAT_MOD_VENDOR_QCOM 0x05
#define DRM_FORMAT_MOD_VENDOR_VIVANTE 0x06
#define DRM_FORMAT_MOD_VENDOR_BROADCOM 0x07
#define DRM_FORMAT_MOD_VENDOR_ARM 0x08
#define DRM_FORMAT_MOD_VENDOR_ALLWINNER 0x09
#define DRM_FORMAT_MOD_VENDOR_AMLOGIC 0x0a
#define DRM_FORMAT_RESERVED ((1ULL << 56) - 1)
#define fourcc_mod_code(vendor,val) ((((__u64) DRM_FORMAT_MOD_VENDOR_ ##vendor) << 56) | ((val) & 0x00ffffffffffffffULL))
#define DRM_FORMAT_MOD_GENERIC_16_16_TILE DRM_FORMAT_MOD_SAMSUNG_16_16_TILE
#define DRM_FORMAT_MOD_INVALID fourcc_mod_code(NONE, DRM_FORMAT_RESERVED)
#define DRM_FORMAT_MOD_LINEAR fourcc_mod_code(NONE, 0)
#define I915_FORMAT_MOD_X_TILED fourcc_mod_code(INTEL, 1)
#define I915_FORMAT_MOD_Y_TILED fourcc_mod_code(INTEL, 2)
#define I915_FORMAT_MOD_Yf_TILED fourcc_mod_code(INTEL, 3)
#define I915_FORMAT_MOD_Y_TILED_CCS fourcc_mod_code(INTEL, 4)
#define I915_FORMAT_MOD_Yf_TILED_CCS fourcc_mod_code(INTEL, 5)
#define I915_FORMAT_MOD_Y_TILED_GEN12_RC_CCS fourcc_mod_code(INTEL, 6)
#define I915_FORMAT_MOD_Y_TILED_GEN12_MC_CCS fourcc_mod_code(INTEL, 7)
#define DRM_FORMAT_MOD_SAMSUNG_64_32_TILE fourcc_mod_code(SAMSUNG, 1)
#define DRM_FORMAT_MOD_SAMSUNG_16_16_TILE fourcc_mod_code(SAMSUNG, 2)
#define DRM_FORMAT_MOD_QCOM_COMPRESSED fourcc_mod_code(QCOM, 1)
#define DRM_FORMAT_MOD_VIVANTE_TILED fourcc_mod_code(VIVANTE, 1)
#define DRM_FORMAT_MOD_VIVANTE_SUPER_TILED fourcc_mod_code(VIVANTE, 2)
#define DRM_FORMAT_MOD_VIVANTE_SPLIT_TILED fourcc_mod_code(VIVANTE, 3)
#define DRM_FORMAT_MOD_VIVANTE_SPLIT_SUPER_TILED fourcc_mod_code(VIVANTE, 4)
#define DRM_FORMAT_MOD_NVIDIA_TEGRA_TILED fourcc_mod_code(NVIDIA, 1)
#define DRM_FORMAT_MOD_NVIDIA_BLOCK_LINEAR_2D(c,s,g,k,h) fourcc_mod_code(NVIDIA, (0x10 | ((h) & 0xf) | (((k) & 0xff) << 12) | (((g) & 0x3) << 20) | (((s) & 0x1) << 22) | (((c) & 0x7) << 23)))
#define DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK(v) DRM_FORMAT_MOD_NVIDIA_BLOCK_LINEAR_2D(0, 0, 0, 0, (v))
#define DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK_ONE_GOB DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK(0)
#define DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK_TWO_GOB DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK(1)
#define DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK_FOUR_GOB DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK(2)
#define DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK_EIGHT_GOB DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK(3)
#define DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK_SIXTEEN_GOB DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK(4)
#define DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK_THIRTYTWO_GOB DRM_FORMAT_MOD_NVIDIA_16BX2_BLOCK(5)
#define __fourcc_mod_broadcom_param_shift 8
#define __fourcc_mod_broadcom_param_bits 48
#define fourcc_mod_broadcom_code(val,params) fourcc_mod_code(BROADCOM, ((((__u64) params) << __fourcc_mod_broadcom_param_shift) | val))
#define fourcc_mod_broadcom_param(m) ((int) (((m) >> __fourcc_mod_broadcom_param_shift) & ((1ULL << __fourcc_mod_broadcom_param_bits) - 1)))
#define fourcc_mod_broadcom_mod(m) ((m) & ~(((1ULL << __fourcc_mod_broadcom_param_bits) - 1) << __fourcc_mod_broadcom_param_shift))
#define DRM_FORMAT_MOD_BROADCOM_VC4_T_TILED fourcc_mod_code(BROADCOM, 1)
#define DRM_FORMAT_MOD_BROADCOM_SAND32_COL_HEIGHT(v) fourcc_mod_broadcom_code(2, v)
#define DRM_FORMAT_MOD_BROADCOM_SAND64_COL_HEIGHT(v) fourcc_mod_broadcom_code(3, v)
#define DRM_FORMAT_MOD_BROADCOM_SAND128_COL_HEIGHT(v) fourcc_mod_broadcom_code(4, v)
#define DRM_FORMAT_MOD_BROADCOM_SAND256_COL_HEIGHT(v) fourcc_mod_broadcom_code(5, v)
#define DRM_FORMAT_MOD_BROADCOM_SAND32 DRM_FORMAT_MOD_BROADCOM_SAND32_COL_HEIGHT(0)
#define DRM_FORMAT_MOD_BROADCOM_SAND64 DRM_FORMAT_MOD_BROADCOM_SAND64_COL_HEIGHT(0)
#define DRM_FORMAT_MOD_BROADCOM_SAND128 DRM_FORMAT_MOD_BROADCOM_SAND128_COL_HEIGHT(0)
#define DRM_FORMAT_MOD_BROADCOM_SAND256 DRM_FORMAT_MOD_BROADCOM_SAND256_COL_HEIGHT(0)
#define DRM_FORMAT_MOD_BROADCOM_UIF fourcc_mod_code(BROADCOM, 6)
#define DRM_FORMAT_MOD_ARM_CODE(__type,__val) fourcc_mod_code(ARM, ((__u64) (__type) << 52) | ((__val) & 0x000fffffffffffffULL))
#define DRM_FORMAT_MOD_ARM_TYPE_AFBC 0x00
#define DRM_FORMAT_MOD_ARM_TYPE_MISC 0x01
#define DRM_FORMAT_MOD_ARM_AFBC(__afbc_mode) DRM_FORMAT_MOD_ARM_CODE(DRM_FORMAT_MOD_ARM_TYPE_AFBC, __afbc_mode)
#define AFBC_FORMAT_MOD_BLOCK_SIZE_MASK 0xf
#define AFBC_FORMAT_MOD_BLOCK_SIZE_16x16 (1ULL)
#define AFBC_FORMAT_MOD_BLOCK_SIZE_32x8 (2ULL)
#define AFBC_FORMAT_MOD_BLOCK_SIZE_64x4 (3ULL)
#define AFBC_FORMAT_MOD_BLOCK_SIZE_32x8_64x4 (4ULL)
#define AFBC_FORMAT_MOD_YTR (1ULL << 4)
#define AFBC_FORMAT_MOD_SPLIT (1ULL << 5)
#define AFBC_FORMAT_MOD_SPARSE (1ULL << 6)
#define AFBC_FORMAT_MOD_CBR (1ULL << 7)
#define AFBC_FORMAT_MOD_TILED (1ULL << 8)
#define AFBC_FORMAT_MOD_SC (1ULL << 9)
#define AFBC_FORMAT_MOD_DB (1ULL << 10)
#define AFBC_FORMAT_MOD_BCH (1ULL << 11)
#define AFBC_FORMAT_MOD_USM (1ULL << 12)
#define DRM_FORMAT_MOD_ARM_16X16_BLOCK_U_INTERLEAVED DRM_FORMAT_MOD_ARM_CODE(DRM_FORMAT_MOD_ARM_TYPE_MISC, 1ULL)
#define DRM_FORMAT_MOD_ALLWINNER_TILED fourcc_mod_code(ALLWINNER, 1)
#define __fourcc_mod_amlogic_layout_mask 0xf
#define __fourcc_mod_amlogic_options_shift 8
#define __fourcc_mod_amlogic_options_mask 0xf
#define DRM_FORMAT_MOD_AMLOGIC_FBC(__layout,__options) fourcc_mod_code(AMLOGIC, ((__layout) & __fourcc_mod_amlogic_layout_mask) | (((__options) & __fourcc_mod_amlogic_options_mask) << __fourcc_mod_amlogic_options_shift))
#define AMLOGIC_FBC_LAYOUT_BASIC (1ULL)
#define AMLOGIC_FBC_LAYOUT_SCATTER (2ULL)
#define AMLOGIC_FBC_OPTION_MEM_SAVING (1ULL << 0)
#ifdef __cplusplus
}
#endif
#endif