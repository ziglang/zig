/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifdef __cplusplus
extern "C"{
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

  MIDL_DEFINE_GUID(IID,IID_IExchangeServer,0x25150F47,0x5734,0x11d2,0xA5,0x93,0x00,0xC0,0x4F,0x99,0x0D,0x8A);
  MIDL_DEFINE_GUID(IID,IID_IStorageGroup,0x25150F46,0x5734,0x11d2,0xA5,0x93,0x00,0xC0,0x4F,0x99,0x0D,0x8A);
  MIDL_DEFINE_GUID(IID,IID_IPublicStoreDB,0x25150F44,0x5734,0x11d2,0xA5,0x93,0x00,0xC0,0x4F,0x99,0x0D,0x8A);
  MIDL_DEFINE_GUID(IID,IID_IMailboxStoreDB,0x25150F45,0x5734,0x11d2,0xA5,0x93,0x00,0xC0,0x4F,0x99,0x0D,0x8A);
  MIDL_DEFINE_GUID(IID,IID_IFolderTree,0x25150F43,0x5734,0x11d2,0xA5,0x93,0x00,0xC0,0x4F,0x99,0x0D,0x8A);
  MIDL_DEFINE_GUID(IID,IID_IDataSource2,0x25150F48,0x5734,0x11d2,0xA5,0x93,0x00,0xC0,0x4F,0x99,0x0D,0x8A);

#undef MIDL_DEFINE_GUID

#ifdef __cplusplus
}
#endif
