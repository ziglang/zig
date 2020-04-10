/* cguid-uuid.c */
/* Generate GUIDs for CGUID interfaces */

/* All IIDs defined in this file were extracted from
 * HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Interface\ */

/* All CLSIDs defined in this file were extracted from
 * HKEY_CLASSES_ROOT\CLSID\ */

#define INITGUID
#include <basetyps.h>
DEFINE_OLEGUID(IID_IRpcChannel,0x4,0,0);
DEFINE_OLEGUID(IID_IRpcStub,0x5,0,0);
DEFINE_OLEGUID(IID_IRpcProxy,0x7,0,0);
DEFINE_OLEGUID(IID_IPSFactory,0x9,0,0);
// Picture (Device Independant Bitmap) CLSID
DEFINE_OLEGUID(CLSID_StaticDib,0x316,0,0);
// Picture (Metafile) CLSID
DEFINE_OLEGUID(CLSID_StaticMetafile,0x315,0,0);
