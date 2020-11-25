/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef __AUDIOSESSIONTYPES__
#define __AUDIOSESSIONTYPES__

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#if defined (__WIDL__)
#define MIDL_SIZE_IS(x) [size_is (x)]
#define MIDL_STRING [string]
#define MIDL_ANYSIZE_ARRAY
#else
#define MIDL_SIZE_IS(x)
#define MIDL_STRING
#define MIDL_ANYSIZE_ARRAY ANYSIZE_ARRAY
#endif

typedef enum _AudioSessionState {
  AudioSessionStateInactive = 0,
  AudioSessionStateActive = 1,
  AudioSessionStateExpired = 2
} AudioSessionState;

typedef enum _AUDCLNT_SHAREMODE {
  AUDCLNT_SHAREMODE_SHARED,
  AUDCLNT_SHAREMODE_EXCLUSIVE
} AUDCLNT_SHAREMODE;

typedef enum _AUDIO_STREAM_CATEGORY {
  AudioCategory_Other = 0,
  AudioCategory_ForegroundOnlyMedia,
  AudioCategory_BackgroundCapableMedia,
  AudioCategory_Communications,
  AudioCategory_Alerts,
  AudioCategory_SoundEffects,
  AudioCategory_GameEffects,
  AudioCategory_GameMedia,
  AudioCategory_GameChat,
  AudioCategory_Speech,
  AudioCategory_Movie,
  AudioCategory_Media
} AUDIO_STREAM_CATEGORY;

#define AUDCLNT_STREAMFLAGS_CROSSPROCESS 0x00010000
#define AUDCLNT_STREAMFLAGS_LOOPBACK 0x00020000
#define AUDCLNT_STREAMFLAGS_EVENTCALLBACK 0x00040000
#define AUDCLNT_STREAMFLAGS_NOPERSIST 0x00080000
#define AUDCLNT_STREAMFLAGS_RATEADJUST 0x00100000
#define AUDCLNT_SESSIONFLAGS_EXPIREWHENUNOWNED 0x10000000
#define AUDCLNT_SESSIONFLAGS_DISPLAY_HIDE 0x20000000
#define AUDCLNT_SESSIONFLAGS_DISPLAY_HIDEWHENEXPIRED 0x40000000

#endif
#endif
