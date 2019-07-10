/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __STORPROP_H__
#define __STORPROP_H__

#include <setupapi.h>

#define REDBOOK_DIGITAL_AUDIO_EXTRACTION_INFO_VERSION 1

typedef struct _REDBOOK_DIGITAL_AUDIO_EXTRACTION_INFO {
  ULONG Version;
  ULONG Accurate;
  ULONG Supported;
  ULONG AccurateMask0;
} REDBOOK_DIGITAL_AUDIO_EXTRACTION_INFO,*PREDBOOK_DIGITAL_AUDIO_EXTRACTION_INFO;

DWORD CdromCddaInfo(HDEVINFO HDevInfo,PSP_DEVINFO_DATA DevInfoData,PREDBOOK_DIGITAL_AUDIO_EXTRACTION_INFO CddaInfo,PULONG BufferSize);
WINBOOL CdromKnownGoodDigitalPlayback(HDEVINFO HDevInfo,PSP_DEVINFO_DATA DevInfoData);
LONG CdromEnableDigitalPlayback(HDEVINFO DevInfo,PSP_DEVINFO_DATA DevInfoData,BOOLEAN ForceUnknown);
LONG CdromDisableDigitalPlayback(HDEVINFO DevInfo,PSP_DEVINFO_DATA DevInfoData);
LONG CdromIsDigitalPlaybackEnabled(HDEVINFO DevInfo,PSP_DEVINFO_DATA DevInfoData,PBOOLEAN Enabled);

#endif
