/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __INC_MPEG2BITS__
#define __INC_MPEG2BITS__
#include <windef.h>

typedef struct _MPEG_HEADER_BITS {
  WORD SectionLength  :12;
  WORD Reserved  :2;
  WORD PrivateIndicator  :1;
  WORD SectionSyntaxIndicator  :1;
} MPEG_HEADER_BITS, *PMPEG_HEADER_BITS;

typedef struct _MPEG_HEADER_VERSION_BITS {
  BYTE CurrentNextIndicator  :1;
  BYTE VersionNumber  :5;
  BYTE Reserved  :2;
} MPEG_HEADER_VERSION_BITS, *PMPEG_HEADER_VERSION_BITS;

#endif /* __INC_MPEG2BITS__ */
