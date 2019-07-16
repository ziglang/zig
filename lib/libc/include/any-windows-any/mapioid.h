/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MAPIOID_
#define _MAPIOID_

#define OID_TAG 0x0A
#define OID_ENCODING 0x0B

#define DEFINE_OID_1(name,b0,b1) EXTERN_C const BYTE *name
#define DEFINE_OID_2(name,b0,b1,b2) EXTERN_C const BYTE *name
#define DEFINE_OID_3(name,b0,b1,b2,b3) EXTERN_C const BYTE *name
#define DEFINE_OID_4(name,b0,b1,b2,b3,b4) EXTERN_C const BYTE *name

#define CB_OID_1 9
#define CB_OID_2 10
#define CB_OID_3 11
#define CB_OID_4 12

#ifdef INITOID
#include <initoid.h>
#endif

#ifdef USES_OID_TNEF
DEFINE_OID_1(OID_TNEF,OID_TAG,0x01);
#define CB_OID_TNEF CB_OID_1
#endif

#ifdef USES_OID_OLE
DEFINE_OID_1(OID_OLE,OID_TAG,0x03);
#define CB_OID_OLE CB_OID_1
#endif

#ifdef USES_OID_OLE1
DEFINE_OID_2(OID_OLE1,OID_TAG,0x03,0x01);
#define CB_OID_OLE1 CB_OID_2
#endif

#ifdef USES_OID_OLE1_STORAGE
DEFINE_OID_3(OID_OLE1_STORAGE,OID_TAG,0x03,0x01,0x01);
#define CB_OID_OLE1_STORAGE CB_OID_3
#endif

#ifdef USES_OID_OLE2
DEFINE_OID_2(OID_OLE2,OID_TAG,0x03,0x02);
#define CB_OID_OLE2 CB_OID_2
#endif

#ifdef USES_OID_OLE2_STORAGE
DEFINE_OID_3(OID_OLE2_STORAGE,OID_TAG,0x03,0x02,0x01);
#define CB_OID_OLE2_STORAGE CB_OID_3
#endif

#ifdef USES_OID_MAC_BINARY
DEFINE_OID_1(OID_MAC_BINARY,OID_ENCODING,0x01);
#define CB_OID_MAC_BINARY CB_OID_1
#endif

#ifdef USES_OID_MIMETAG
DEFINE_OID_1(OID_MIMETAG,OID_TAG,0x04);
#define CB_OID_MIMETAG CB_OID_1
#endif
#endif
