/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef GUID_DEFINED
#define GUID_DEFINED

/* Make sure __LONG32 is defined.  */
#include <_mingw.h>

#ifdef __WIDL__
typedef struct {
  unsigned long Data1;
  unsigned short Data2;
  unsigned short Data3;
  byte Data4[8];
} GUID;
#else
typedef struct _GUID {
  unsigned __LONG32 Data1;
  unsigned short Data2;
  unsigned short Data3;
  unsigned char Data4[8];
} GUID;
#endif
#endif

#if defined(__cplusplus) && (USE___UUIDOF == 0)
extern "C++" {
#if __cpp_constexpr >= 200704l && __cpp_inline_variables >= 201606L
__extension__ template<typename T> struct __mingw_uuidof_s;
__extension__ template<typename T> constexpr const GUID &__mingw_uuidof();
#else
__extension__ template<typename T> const GUID &__mingw_uuidof();
#endif
}
#endif

#ifndef FAR
#define FAR
#endif

#ifndef DECLSPEC_SELECTANY
#define DECLSPEC_SELECTANY __declspec(selectany)
#endif

#ifndef EXTERN_C
#ifdef __cplusplus
#define EXTERN_C extern "C"
#else
#define EXTERN_C extern
#endif
#endif

#ifdef DEFINE_GUID
#undef DEFINE_GUID
#endif

#ifdef INITGUID
#ifdef __cplusplus
#define DEFINE_GUID(name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8) EXTERN_C const GUID DECLSPEC_SELECTANY name = { l, w1, w2, { b1, b2, b3, b4, b5, b6, b7, b8 } }
#else
#define DEFINE_GUID(name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8) const GUID DECLSPEC_SELECTANY name = { l, w1, w2, { b1, b2, b3, b4, b5, b6, b7, b8 } }
#endif
#else
/* __declspec(selectany) must be applied to initialized objects on GCC 5 hence must not be used here. */
#define DEFINE_GUID(name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8) EXTERN_C const GUID name
#endif

#define DEFINE_OLEGUID(name, l, w1, w2) DEFINE_GUID (name, l, w1, w2, 0xc0, 0, 0, 0, 0, 0, 0, 0x46)

#ifndef _GUIDDEF_H_
#define _GUIDDEF_H_

#ifndef __LPGUID_DEFINED__
#define __LPGUID_DEFINED__
typedef GUID *LPGUID;
#endif

#ifndef __LPCGUID_DEFINED__
#define __LPCGUID_DEFINED__
typedef const GUID *LPCGUID;
#endif

#ifndef __IID_DEFINED__
#define __IID_DEFINED__

typedef GUID IID;
typedef IID *LPIID;

#define IID_NULL GUID_NULL
#define IsEqualIID(riid1, riid2) IsEqualGUID (riid1, riid2)

#ifndef CLSID_DEFINED
#define CLSID_DEFINED
typedef GUID CLSID;
#endif

typedef CLSID *LPCLSID;

#define CLSID_NULL GUID_NULL
#define IsEqualCLSID(rclsid1, rclsid2) IsEqualGUID (rclsid1, rclsid2)
typedef GUID FMTID;
typedef FMTID *LPFMTID;
#define FMTID_NULL GUID_NULL
#define IsEqualFMTID(rfmtid1, rfmtid2) IsEqualGUID (rfmtid1, rfmtid2)

#ifdef __WIDL_proxy
#define __MIDL_CONST
#else
#define __MIDL_CONST const
#endif

#ifndef _REFGUID_DEFINED
#define _REFGUID_DEFINED
#ifdef __cplusplus
#define REFGUID const GUID &
#else
#define REFGUID const GUID *__MIDL_CONST
#endif
#endif

#ifndef _REFIID_DEFINED
#define _REFIID_DEFINED
#ifdef __cplusplus
#define REFIID const IID &
#else
#define REFIID const IID *__MIDL_CONST
#endif
#endif

#ifndef _REFCLSID_DEFINED
#define _REFCLSID_DEFINED
#ifdef __cplusplus
#define REFCLSID const IID &
#else
#define REFCLSID const IID *__MIDL_CONST
#endif
#endif

#ifndef _REFFMTID_DEFINED
#define _REFFMTID_DEFINED
#ifdef __cplusplus
#define REFFMTID const IID &
#else
#define REFFMTID const IID *__MIDL_CONST
#endif
#endif
#endif

#ifndef __WIDL__
#ifndef _SYS_GUID_OPERATORS_
#define _SYS_GUID_OPERATORS_
#include <string.h>

#ifdef __cplusplus
__inline int InlineIsEqualGUID (REFGUID rguid1, REFGUID rguid2) {
  return ((&rguid1.Data1)[0] == (&rguid2.Data1)[0] && (&rguid1.Data1)[1] == (&rguid2.Data1)[1] && (&rguid1.Data1)[2] == (&rguid2.Data1)[2] && (&rguid1.Data1)[3] == (&rguid2.Data1)[3]);
}

__inline int IsEqualGUID (REFGUID rguid1, REFGUID rguid2) {
  return !memcmp (&rguid1,&rguid2, sizeof (GUID));
}
#else
#define InlineIsEqualGUID(rguid1, rguid2) ((&(rguid1)->Data1)[0] == (&(rguid2)->Data1)[0] && (&(rguid1)->Data1)[1] == (&(rguid2)->Data1)[1] && (&(rguid1)->Data1)[2] == (&(rguid2)->Data1)[2] && (&(rguid1)->Data1)[3] == (&(rguid2)->Data1)[3])
#define IsEqualGUID(rguid1, rguid2) (!memcmp (rguid1, rguid2, sizeof (GUID)))
#endif

#ifdef __INLINE_ISEQUAL_GUID
#undef IsEqualGUID
#define IsEqualGUID(rguid1, rguid2) InlineIsEqualGUID (rguid1, rguid2)
#endif

#define IsEqualIID(riid1, riid2) IsEqualGUID (riid1, riid2)
#define IsEqualCLSID(rclsid1, rclsid2) IsEqualGUID (rclsid1, rclsid2)

#if !defined (_SYS_GUID_OPERATOR_EQ_) && !defined (_NO_SYS_GUID_OPERATOR_EQ_)
#define _SYS_GUID_OPERATOR_EQ_
#ifdef __cplusplus
__inline bool operator== (REFGUID guidOne, REFGUID guidOther) { return !!IsEqualGUID (guidOne, guidOther); }
__inline bool operator!= (REFGUID guidOne, REFGUID guidOther) { return ! (guidOne == guidOther); }
#endif
#endif

#endif
#endif
#endif
