/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INCL_NTMSMLI_H_
#define _INCL_NTMSMLI_H_

#define NTMSMLI_MAXTYPE 64
#define NTMSMLI_MAXIDSIZE 256
#define NTMSMLI_MAXAPPDESCR 256

#ifndef NTMS_NOREDEF

typedef struct {
  WCHAR LabelType[NTMSMLI_MAXTYPE];
  DWORD LabelIDSize;
  BYTE LabelID[NTMSMLI_MAXIDSIZE];
  WCHAR LabelAppDescr[NTMSMLI_MAXAPPDESCR];
} MediaLabelInfo,*pMediaLabelInfo;
#endif

typedef DWORD (WINAPI *MAXMEDIALABEL)(DWORD *const pMaxSize);
typedef DWORD (WINAPI *CLAIMMEDIALABEL)(const BYTE *const pBuffer,const DWORD nBufferSize,MediaLabelInfo *const pLabelInfo);
typedef DWORD (WINAPI *CLAIMMEDIALABELEX)(const BYTE *const pBuffer,const DWORD nBufferSize,MediaLabelInfo *const pLabelInfo,GUID *LabelGuid);
#endif
