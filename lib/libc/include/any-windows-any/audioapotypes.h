/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
typedef LONGLONG HNSTIME;
typedef LONGLONG MFTIME;
typedef float FLOAT32;
typedef double FLOAT64;

typedef enum APO_BUFFER_FLAGS {
  BUFFER_INVALID = 0,
  BUFFER_VALID = 1,
  BUFFER_SILENT = 2
} APO_BUFFER_FLAGS;

typedef struct APO_CONNECTION_PROPERTY {
  UINT_PTR pBuffer;
  UINT32 u32ValidFrameCount;
  APO_BUFFER_FLAGS u32BufferFlags;
  UINT32 u32Signature;
} APO_CONNECTION_PROPERTY;

#ifndef _AUDIO_CURVE_TYPE_
#define _AUDIO_CURVE_TYPE_

typedef enum {
  AUDIO_CURVE_TYPE_NONE = 0,
  AUDIO_CURVE_TYPE_WINDOWS_FADE = 1
} AUDIO_CURVE_TYPE;
#endif

#endif
