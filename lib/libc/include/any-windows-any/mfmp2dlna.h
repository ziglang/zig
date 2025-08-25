/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_MFMP2DLNA
#define _INC_MFMP2DLNA

#if (WINVER >= 0x0601)
#ifdef __cplusplus
extern "C" {
#endif
typedef struct _MFMPEG2DLNASINKSTATS {
  DWORDLONG cBytesWritten;
  BOOL      fPAL;
  DWORD     fccVideo;
  DWORD     dwVideoWidth;
  DWORD     dwVideoHeight;
  DWORDLONG cVideoFramesReceived;
  DWORDLONG cVideoFramesEncoded;
  DWORDLONG cVideoFramesSkipped;
  DWORDLONG cBlackVideoFramesEncoded;
  DWORDLONG cVideoFramesDuplicated;
  DWORD     cAudioSamplesPerSec;
  DWORD     cAudioChannels;
  DWORDLONG cAudioBytesReceived;
  DWORDLONG cAudioFramesEncoded;
} MFMPEG2DLNASINKSTATS;
#ifdef __cplusplus
}
#endif
#endif /*(WINVER >= 0x0601)*/
#endif /*_INC_MFMP2DLNA*/
