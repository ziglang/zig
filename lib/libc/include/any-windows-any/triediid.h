/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _triediid_h_
#define _triediid_h_

#ifdef __cplusplus
extern "C"{
#endif

  EXTERN_C const GUID GUID_TriEditCommandGroup;
  EXTERN_C const IID IID_ITriEditDocument;
  EXTERN_C const IID LIBID_TRIEDITLib;
  EXTERN_C const CLSID CLSID_TriEditDocument;

  DEFINE_GUID(GUID_TriEditCommandGroup,0x2582f1c0,0x084e,0x11d1,0x9a,0x0e,0x00,0x60,0x97,0xc9,0xb3,0x44);
  DEFINE_GUID(IID_ITriEditDocument,0x438DA5DF,0xF171,0x11D0,0x98,0x4E,0x00,0x00,0xF8,0x02,0x70,0xF8);
  DEFINE_GUID(LIBID_TRIEDITLib,0x438DA5D1,0xF171,0x11D0,0x98,0x4E,0x00,0x00,0xF8,0x02,0x70,0xF8);
  DEFINE_GUID(CLSID_TriEditDocument,0x438DA5E0,0xF171,0x11D0,0x98,0x4E,0x00,0x00,0xF8,0x02,0x70,0xF8);

#ifdef __cplusplus
}
#endif
#endif
