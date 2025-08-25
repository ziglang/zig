/* olectlid-uuid.c */
/* Generate GUIDs for OLECTLID interfaces */

/* All IIDs defined in this file were extracted from
 * HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Interface\ */

/* All CLSIDs defined in this file were extracted from
 * HKEY_CLASSES_ROOT\CLSID\ */

#define INITGUID
#include <basetyps.h>
DEFINE_OLEGUID(IID_IDispatch,0x20400,0,0);
DEFINE_OLEGUID(IID_IEnumUnknown,0x100,0,0);
DEFINE_OLEGUID(IID_IEnumString,0x101,0,0);
DEFINE_OLEGUID(IID_IEnumMoniker,0x102,0,0);
DEFINE_OLEGUID(IID_IEnumFORMATETC,0x103,0,0);
DEFINE_OLEGUID(IID_IEnumOLEVERB,0x104,0,0);
DEFINE_OLEGUID(IID_IEnumSTATDATA,0x105,0,0);
DEFINE_OLEGUID(IID_IEnumSTATSTG,0xd,0,0);
DEFINE_OLEGUID(IID_IOleLink,0x11d,0,0);
DEFINE_OLEGUID(IID_IDebug,0x123,0,0);
DEFINE_OLEGUID(IID_IDebugStream,0x124,0,0);
// Font Property Page CLSID
DEFINE_GUID(CLSID_CFontPropPage, 0x0be35200,0x8f91,0x11ce,0x9d,0xe3,0x00,0xaa,0x00,0x4b,0xb8,0x51);
// Color Property Page CLSID
DEFINE_GUID(CLSID_CColorPropPage,0xbe35201,0x8f91,0x11ce,0x9d,0xe3,0,0xaa,0,0x4b,0xb8,0x51);
// Picture Property Page CLSID
DEFINE_GUID(CLSID_CPicturePropPage,0xbe35202,0x8f91,0x11ce,0x9d,0xe3,0,0xaa,0,0x4b,0xb8,0x51);
// Standard Font CLSID
DEFINE_GUID(CLSID_StdFont,0xbe35203,0x8f91,0x11ce,0x9d,0xe3,0,0xaa,0,0x4b,0xb8,0x51);
// Standard Picture CLSID
DEFINE_GUID(CLSID_StdPicture,0xbe35204,0x8f91,0x11ce,0x9d,0xe3,0,0xaa,0,0x4b,0xb8,0x51);
// Picture (Metafile) CLSID
DEFINE_OLEGUID(CLSID_Picture_Metafile,0x315,0,0);
// Picture (Device Independent Bitmap) CLSID
DEFINE_OLEGUID(CLSID_Picture_Dib,0x316,0,0);
