/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __INC_SBE__
#define __INC_SBE__
#include <dshow.h>

typedef struct _DVR_STREAM_DESC {
  DWORD         version;
  DWORD         StreamId;
  WINBOOL       Default;
  WINBOOL       Creation;
  DWORD         Reserved;
  GUID          guidSubMediaType;
  GUID          guidFormatType;
  AM_MEDIA_TYPE MediaType;
} DVR_STREAM_DESC, *PDVR_STREAM_DESC;

#endif /*__INC_SBE__*/
