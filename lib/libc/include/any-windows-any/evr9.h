/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EVR9
#define _INC_EVR9

#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _evr9_tag_MFVideoAlphaBitmapFlags {
  MFVideoAlphaBitmap_EntireDDS     = 0x00000001,
  MFVideoAlphaBitmap_SrcColorKey   = 0x00000002,
  MFVideoAlphaBitmap_SrcRect       = 0x00000004,
  MFVideoAlphaBitmap_DestRect      = 0x00000008,
  MFVideoAlphaBitmap_FilterMode    = 0x00000010,
  MFVideoAlphaBitmap_Alpha         = 0x00000020,
  MFVideoAlphaBitmap_BitMask       = 0x0000003f 
} MFVideoAlphaBitmapFlags;

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_EVR9*/
