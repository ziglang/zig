/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef AXEXTEND_ENUM_H
#define AXEXTEND_ENUM_H

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
typedef
#ifdef __WIDL__
  [v1_enum]
#endif
  enum tagAnalogVideoStandard {
  AnalogVideo_None = 0x0,
  AnalogVideo_NTSC_M = 0x1,
  AnalogVideo_NTSC_M_J = 0x2,
  AnalogVideo_NTSC_433 = 0x4,
  AnalogVideo_PAL_B = 0x10,
  AnalogVideo_PAL_D = 0x20,
  AnalogVideo_PAL_G = 0x40,
  AnalogVideo_PAL_H = 0x80,
  AnalogVideo_PAL_I = 0x100,
  AnalogVideo_PAL_M = 0x200,
  AnalogVideo_PAL_N = 0x400,
  AnalogVideo_PAL_60 = 0x800,
  AnalogVideo_SECAM_B = 0x1000,
  AnalogVideo_SECAM_D = 0x2000,
  AnalogVideo_SECAM_G = 0x4000,
  AnalogVideo_SECAM_H = 0x8000,
  AnalogVideo_SECAM_K = 0x10000,
  AnalogVideo_SECAM_K1 = 0x20000,
  AnalogVideo_SECAM_L = 0x40000,
  AnalogVideo_SECAM_L1 = 0x80000,
  AnalogVideo_PAL_N_COMBO = 0x100000,

  AnalogVideoMask_MCE_NTSC = AnalogVideo_NTSC_M | AnalogVideo_NTSC_M_J | AnalogVideo_NTSC_433 | AnalogVideo_PAL_M | AnalogVideo_PAL_N | AnalogVideo_PAL_60 | AnalogVideo_PAL_N_COMBO,
  AnalogVideoMask_MCE_PAL = AnalogVideo_PAL_B | AnalogVideo_PAL_D | AnalogVideo_PAL_G | AnalogVideo_PAL_H | AnalogVideo_PAL_I,
  AnalogVideoMask_MCE_SECAM = AnalogVideo_SECAM_B | AnalogVideo_SECAM_D | AnalogVideo_SECAM_G | AnalogVideo_SECAM_H | AnalogVideo_SECAM_K | AnalogVideo_SECAM_K1 | AnalogVideo_SECAM_L | AnalogVideo_SECAM_L1
} AnalogVideoStandard;

typedef
#ifdef __WIDL__
  [v1_enum]
#endif
enum tagTunerInputType {
  TunerInputCable,
  TunerInputAntenna
} TunerInputType;

#endif
#endif
