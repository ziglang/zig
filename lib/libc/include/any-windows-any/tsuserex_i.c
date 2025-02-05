/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifdef __cplusplus
extern "C" {
#endif

#include <rpc.h>
#include <rpcndr.h>

#ifdef _MIDL_USE_GUIDDEF_

#ifndef INITGUID
#define INITGUID
#include <guiddef.h>
#undef INITGUID
#else
#include <guiddef.h>
#endif

#define MIDL_DEFINE_GUID(type,name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8) DEFINE_GUID(name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8)
#else

#ifndef __IID_DEFINED__
#define __IID_DEFINED__
  typedef struct _IID {
    unsigned long x;
    unsigned short s1;
    unsigned short s2;
    unsigned char c[8];
  } IID;
#endif

#ifndef CLSID_DEFINED
#define CLSID_DEFINED
  typedef IID CLSID;
#endif

#define MIDL_DEFINE_GUID(type,name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8) const type name = {l,w1,w2,{b1,b2,b3,b4,b5,b6,b7,b8}}
#endif

  MIDL_DEFINE_GUID(IID,LIBID_TSUSEREXLib,0x45413F04,0xDF86,0x11D1,0xAE,0x27,0x00,0xC0,0x4F,0xA3,0x58,0x13);
  MIDL_DEFINE_GUID(CLSID,CLSID_TSUserExInterfaces,0x0910dd01,0xdf8c,0x11d1,0xae,0x27,0x00,0xc0,0x4f,0xa3,0x58,0x13);
  MIDL_DEFINE_GUID(IID,IID_IADsTSUserEx,0xC4930E79,0x2989,0x4462,0x8A,0x60,0x2F,0xCF,0x2F,0x29,0x55,0xEF);
  MIDL_DEFINE_GUID(CLSID,CLSID_ADsTSUserEx,0xE2E9CAE6,0x1E7B,0x4B8E,0xBA,0xBD,0xE9,0xBF,0x62,0x92,0xAC,0x29);

#undef MIDL_DEFINE_GUID

#ifdef __cplusplus
}
#endif
